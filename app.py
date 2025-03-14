import os
import time
import random
import requests
import json
import redis
import psycopg2
from psycopg2 import sql
from datetime import datetime, timedelta
import logging
import re

# 设置日志
logging.basicConfig(level=logging.INFO,
                    format='%(asctime)s - %(levelname)s - %(message)s')

# 读取环境变量
API_URL = os.getenv('API_URL', 'http://192.168.0.120:6688')
REDIS_HOST = os.getenv('REDIS_HOST', 'localhost')
REDIS_PORT = int(os.getenv('REDIS_PORT', 6379))
REDIS_DB = int(os.getenv('REDIS_DB', 0))
REDIS_PASSWORD = os.getenv('REDIS_PASSWORD', '')  # Redis 密码
TIMESCALEDB_HOST = os.getenv('TIMESCALEDB_HOST', 'localhost')
TIMESCALEDB_PORT = int(os.getenv('TIMESCALEDB_PORT', 5432))
TIMESCALEDB_USER = os.getenv('TIMESCALEDB_USER', 'postgres')
TIMESCALEDB_PASSWORD = os.getenv('TIMESCALEDB_PASSWORD', 'password')
REDIS2_HOST = os.getenv('REDIS2_HOST', 'localhost')
REDIS2_PORT = int(os.getenv('REDIS2_PORT', 6379))
REDIS2_DB = int(os.getenv('REDIS2_DB', 0))
REDIS2_PASSWORD = os.getenv('REDIS2_PASSWORD', '')

# Redis 缓存键
ROUTES_CACHE_KEY = 'allbs:routes_cache'
# 当前年份缓存键
CURRENT_YEAR_KEY = 'allbs:current_year'

# 初始化 Redis 连接
try:
    redis_client = redis.Redis(
        host=REDIS_HOST,
        port=REDIS_PORT,
        db=REDIS_DB,
        password=REDIS_PASSWORD,  # 传递 Redis 密码
        decode_responses=True  # 将 Redis 响应解码为字符串
    )
    redis_client.ping()
    logging.info("Connected to Redis")
except redis.exceptions.RedisError as e:
    logging.error(f"Redis connection error: {e}")
    exit(1)

# 初始化第二个 Redis 连接
try:
    redis_client2 = redis.Redis(
        host=REDIS2_HOST,
        port=REDIS2_PORT,
        db=REDIS2_DB,
        password=REDIS2_PASSWORD,
        decode_responses=True
    )
    redis_client2.ping()
    logging.info("Connected to second Redis")
except redis.exceptions.RedisError as e:
    logging.error(f"Second Redis connection error: {e}")
    exit(1)

# 全局连接变量
conn = None
cursor = None

def get_db_name_for_year(year):
    """
    根据年份生成数据库名称
    """
    return f"daily_hot_{year}"

# 初始化 TimescaleDB 连接
def init_db_connection(year=None):
    """
    初始化数据库连接，如果指定了年份，则连接到对应年份的数据库
    """
    if year is None:
        year = datetime.now().year
    
    db_name = get_db_name_for_year(year)
    
    try:
        # 先尝试连接到指定年份的数据库
        try:
            conn = psycopg2.connect(
                host=TIMESCALEDB_HOST,
                port=TIMESCALEDB_PORT,
                user=TIMESCALEDB_USER,
                password=TIMESCALEDB_PASSWORD,
                dbname=db_name
            )
            conn.autocommit = True
            cursor = conn.cursor()
            logging.info(f"Connected to TimescaleDB database: {db_name}")
            
            # 检查TimescaleDB扩展是否已安装
            try:
                cursor.execute("CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;")
                logging.info("TimescaleDB extension enabled")
            except psycopg2.Error as e:
                logging.error(f"Error enabling TimescaleDB extension: {e}")
                logging.warning("Some features may not be available without TimescaleDB extension")
            
            return conn, cursor, db_name
        except psycopg2.OperationalError as e:
            # 如果数据库不存在，则创建它
            logging.info(f"Database {db_name} does not exist or connection failed: {e}")
            logging.info(f"Attempting to create database {db_name}...")
            
            # 连接到默认的postgres数据库
            try:
                temp_conn = psycopg2.connect(
                    host=TIMESCALEDB_HOST,
                    port=TIMESCALEDB_PORT,
                    user=TIMESCALEDB_USER,
                    password=TIMESCALEDB_PASSWORD,
                    dbname="postgres"
                )
                temp_conn.autocommit = True
                temp_cursor = temp_conn.cursor()
                
                # 检查数据库是否已存在
                temp_cursor.execute(f"SELECT 1 FROM pg_database WHERE datname = '{db_name}'")
                exists = temp_cursor.fetchone()
                
                if not exists:
                    # 创建数据库
                    temp_cursor.execute(sql.SQL("CREATE DATABASE {}").format(
                        sql.Identifier(db_name)
                    ))
                    logging.info(f"Created database {db_name}")
                else:
                    logging.info(f"Database {db_name} already exists but connection failed")
                
                temp_cursor.close()
                temp_conn.close()
            except psycopg2.Error as e:
                logging.error(f"Error connecting to postgres database or creating {db_name}: {e}")
                raise
            
            # 连接到新创建的数据库
            try:
                conn = psycopg2.connect(
                    host=TIMESCALEDB_HOST,
                    port=TIMESCALEDB_PORT,
                    user=TIMESCALEDB_USER,
                    password=TIMESCALEDB_PASSWORD,
                    dbname=db_name
                )
                conn.autocommit = True
                cursor = conn.cursor()
                
                # 检查TimescaleDB扩展是否已安装
                try:
                    cursor.execute("CREATE EXTENSION IF NOT EXISTS timescaledb CASCADE;")
                    logging.info("TimescaleDB extension enabled")
                except psycopg2.Error as e:
                    logging.error(f"Error enabling TimescaleDB extension: {e}")
                    logging.warning("Some features may not be available without TimescaleDB extension")
                
                return conn, cursor, db_name
            except psycopg2.Error as e:
                logging.error(f"Error connecting to newly created database {db_name}: {e}")
                raise
    except Exception as e:
        logging.error(f"Unexpected error during database initialization: {e}")
        exit(1)

# 初始化当前年份的数据库连接
conn, cursor, current_db = init_db_connection()

def sanitize_table_name(name):
    """
    仅允许字母、数字和下划线，其他字符替换为下划线
    """
    return re.sub(r'\W+', '_', name)

def fetch_all_routes():
    """
    获取 /all 接口的数据
    """
    try:
        response = requests.get(API_URL + "/all", timeout=10)
        response.raise_for_status()
        data = response.json()
        if data.get("code") == 200:
            logging.info("Fetched routes successfully")
            return data
        else:
            logging.error(f"API returned error code: {data.get('code')}")
            return None
    except requests.RequestException as e:
        logging.error(f"Error fetching /all routes: {e}")
        return None

def cache_routes(data):
    """
    将 /all 接口的结果缓存到 Redis
    """
    try:
        redis_client.set(ROUTES_CACHE_KEY, json.dumps(data))
        logging.info("Cached /all routes to Redis")
    except redis.exceptions.RedisError as e:
        logging.error(f"Error caching routes in Redis: {e}")

def get_cached_routes():
    """
    从 Redis 获取缓存的 /all 路由数据
    """
    try:
        cached_data = redis_client.get(ROUTES_CACHE_KEY)
        if cached_data:
            return json.loads(cached_data)
        else:
            logging.error("No cached routes found in Redis")
            return None
    except redis.exceptions.RedisError as e:
        logging.error(f"Error retrieving cached routes from Redis: {e}")
        return None

def ensure_table_exists(base_name):
    """
    检查表是否存在，不存在则创建，并转换为 TimescaleDB 的 hypertable
    """
    table_name = f"records_{base_name}"
    
    try:
        create_table_query = sql.SQL("""
            CREATE TABLE IF NOT EXISTS {} (
                ingestion_time TIMESTAMPTZ NOT NULL DEFAULT NOW(),
                update_time TIMESTAMPTZ NOT NULL,
                title TEXT,
                "desc" TEXT,
                cover TEXT,
                item_timestamp BIGINT,
                hot TEXT,
                url TEXT,
                mobile_url TEXT,
                sort_order TEXT,
                UNIQUE (title, item_timestamp)
            );
        """).format(sql.Identifier(table_name))
        
        try:
            cursor.execute(create_table_query)
            logging.info(f"Table {table_name} created or already exists")
        except psycopg2.Error as e:
            logging.error(f"Error creating table {table_name}: {e}")
            return None

        # 创建hypertable并按时间自动分片
        try:
            create_hypertable_query = sql.SQL("""
                SELECT create_hypertable(%s, 'ingestion_time', 
                                        chunk_time_interval => INTERVAL '1 day', 
                                        if_not_exists => TRUE);
            """)
            cursor.execute(create_hypertable_query, [table_name])
            logging.info(f"Table {table_name} converted to hypertable")
        except psycopg2.Error as e:
            logging.error(f"Error converting {table_name} to hypertable: {e}")
            # 即使转换为hypertable失败，表仍然可以使用
            logging.warning(f"Will use {table_name} as a regular table")

        # 添加保留策略（可选，根据需要保留数据的时间长度调整）
        # cursor.execute(sql.SQL("""
        #     SELECT add_retention_policy(%s, INTERVAL '1 year', if_not_exists => TRUE);
        # """), [table_name])

        logging.info(f"Ensured table {table_name} exists and is hypertable with time-based chunks")
        return table_name
    except Exception as e:
        logging.error(f"Unexpected error ensuring table exists for {table_name}: {e}")
        return None

def get_or_create_db_for_timestamp(base_name, timestamp):
    """
    根据时间戳获取或创建对应年份的数据库，并确保表存在
    """
    global conn, cursor, current_db
    
    # 将时间戳转换为datetime对象
    dt = datetime.fromtimestamp(timestamp / 1000 if timestamp > 1e10 else timestamp)
    year = dt.year
    
    # 检查是否需要切换数据库（跨年）
    current_year = redis_client.get(CURRENT_YEAR_KEY)
    db_name = get_db_name_for_year(year)
    
    if current_year is None or int(current_year) != year or current_db != db_name:
        # 更新当前年份缓存
        redis_client.set(CURRENT_YEAR_KEY, year)
        logging.info(f"Year changed or initialized to {year}")
        
        # 切换到对应年份的数据库
        conn, cursor, current_db = init_db_connection(year)
    
    # 确保表存在
    return ensure_table_exists(base_name)

def insert_into_timescaledb(base_name, update_time, data_item, sort_order):
    """
    将数据插入到 TimescaleDB，避免冗余数据
    """
    global conn, cursor
    try:
        # 获取时间戳
        item_timestamp = data_item.get("timestamp", 0) + (8 * 3600)
        
        # 根据时间戳获取或创建对应年份的数据库和表
        table_name = get_or_create_db_for_timestamp(base_name, item_timestamp)
        if not table_name:
            logging.error(f"Failed to get or create table for {base_name} with timestamp {item_timestamp}")
            return
        
        insert_query = sql.SQL("""
            INSERT INTO {} (update_time, title, "desc", cover, item_timestamp, hot, url, mobile_url, sort_order)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
            ON CONFLICT (title, item_timestamp) DO UPDATE
            SET hot = CONCAT(EXCLUDED.hot, ',', {table}.hot),
                sort_order = CONCAT(EXCLUDED.sort_order, ',', {table}.sort_order)
        """).format(sql.Identifier(table_name), table=sql.Identifier(table_name))

        # 提取需要的字段
        title = data_item.get('title')
        desc = data_item.get('desc')
        cover = data_item.get('cover')
        hot = str(data_item.get('hot', ''))  # 转换为字符串
        url = data_item.get('url')
        mobile_url = data_item.get('mobileUrl')

        cursor.execute(insert_query, [
            update_time,
            title,
            desc,
            cover,
            item_timestamp,
            hot,
            url,
            mobile_url,
            sort_order
        ])
        logging.info(f"Inserted/Updated data into {table_name}: {title}")
    except psycopg2.Error as e:
        logging.error(f"Error inserting/updating data into {table_name}: {e}")
        # 如果是连接错误，尝试重新连接
        if isinstance(e, psycopg2.OperationalError):
            logging.info("Attempting to reconnect to database...")
            year = datetime.fromtimestamp(item_timestamp / 1000 if item_timestamp > 1e10 else item_timestamp).year
            conn, cursor, current_db = init_db_connection(year)

def cache_in_redis_sorted_set(key, data_list):
    """
    使用有序集合（Sorted Set）缓存 data 列表，使用 timestamp 作为分数
    在存储前清除旧数据
    """
    try:
        # 清除现有的有序集合
        redis_client.delete(key)
        logging.info(f"Cleared existing Redis sorted set with key: {key}")

        # 添加新的数据到有序集合
        pipeline = redis_client.pipeline()
        for item in data_list:
            timestamp = item.get('timestamp', 0)
            member = json.dumps(item, ensure_ascii=False)
            pipeline.zadd(key, {member: timestamp})
        pipeline.execute()

        redis_client.expire(key, 3600)
        logging.info(f"Cached {len(data_list)} items in Redis sorted set with key: {key}")

        # 下面新增往第二个 Redis 存储的逻辑，与第一个保持一致
        try:
            redis_client2.delete(key)
            pipeline2 = redis_client2.pipeline()
            for item in data_list:
                timestamp = item.get('timestamp', 0)
                member = json.dumps(item, ensure_ascii=False)
                pipeline2.zadd(key, {member: timestamp})
            pipeline2.execute()

            redis_client2.expire(key, 3600)
            logging.info(f"Cached {len(data_list)} items in second Redis sorted set with key: {key}")
        except redis.exceptions.RedisError as e:
            logging.error(f"Error caching data in second Redis: {e}")
    except redis.exceptions.RedisError as e:
        logging.error(f"Error caching data in Redis: {e}")

def process_initial_routes(all_data):
    """
    处理初始的 /all 路由数据，创建表并缓存
    """
    routes = all_data.get('routes', [])
    if not routes:
        logging.error("No routes found in /all data")
        return

    # 获取当前年份
    current_year = datetime.now().year
    redis_client.set(CURRENT_YEAR_KEY, current_year)
    
    for route in routes:
        name = route.get("name")
        path = route.get("path")
        if not name or not path:
            logging.warning(f"Invalid route data: {route}")
            continue

        sanitized_name = sanitize_table_name(name)
        
        # 确保表存在
        ensure_table_exists(sanitized_name)

    # 缓存 /all 结果
    cache_routes(all_data)

def process_routes_periodic():
    """
    定期任务：使用缓存的 routes 进行数据请求和存储
    """
    logging.info("Starting periodic task")
    cached_routes_data = get_cached_routes()
    if not cached_routes_data:
        logging.error("No cached routes data available for periodic task")
        return

    routes = cached_routes_data.get('routes', [])
    if not routes:
        logging.warning("No routes to process in cached data")
        return

    for route in routes:
        name = route.get("name")
        path = route.get("path")
        if not name or not path:
            logging.warning(f"Invalid route data: {route}")
            continue

        sanitized_name = sanitize_table_name(name)
        key = path.lstrip('/')

        # 构建具体请求的 URL
        request_url = f"{API_URL}{path}"
        logging.info(f"Fetching data from {request_url}")

        try:
            response = requests.get(request_url, timeout=10)
            response.raise_for_status()
            data = response.json()
        except requests.RequestException as e:
            logging.error(f"Error fetching data from {request_url}: {e}")
            continue

        # 缓存数据到 Redis 有序集合
        data_list = data.get('data', [])
        cache_in_redis_sorted_set("allbs:news:" + key, data_list)

        # 提取 updateTime
        update_time_str = data.get('updateTime')
        if not update_time_str:
            logging.warning(f"No updateTime found in data for {name}")
            continue
        try:
            update_time = datetime.fromisoformat(update_time_str.replace('Z', '+00:00')) + timedelta(hours=8)
        except ValueError as e:
            logging.error(f"Invalid updateTime format for {name}: {update_time_str}")
            continue

        # 处理 data 列表并插入到 TimescaleDB
        for index, item in enumerate(data_list):
            insert_into_timescaledb(sanitized_name, update_time, item, str(index))

def initialize():
    """
    初始化函数：调用 /all，处理路由，创建表，缓存结果
    """
    logging.info("Initializing application")
    all_data = fetch_all_routes()
    if all_data:
        process_initial_routes(all_data)
    else:
        logging.error("Failed to initialize routes from /all")
        exit(1)

def run():
    """
    主运行函数：初始化后进入循环，定期执行任务
    """
    initialize()
    while True:
        process_routes_periodic()
        # 随机睡眠 30 分钟到 1 小时
        sleep_time = random.randint(1800, 3600)
        logging.info(f"Sleeping for {sleep_time} seconds")
        time.sleep(sleep_time)

if __name__ == "__main__":
    run()
