-- 构造一个有过期时间且限制大小的queue
-- 每次试图往该list插入新值时，都会先淘汰已过期的元素。并且只有当剩余元素小于max size时，才会插入新元素
-- 当过期时间最晚的一个元素过期后，整个queue都会过期
-- 返回剩余list size （插入新元素前）
-- KEYS[1] list key
-- ARGV[1] list max size
-- ARGV[2] timeout value
local list = KEYS[1]
local list_max_size = tonumber(ARGV[1])
local timeout = tonumber(ARGV[2])
local future_ts = 2000000000
redis.call('setnx', 'future', 1)
redis.call('expireat', 'future', future_ts)
local current_ts = future_ts - redis.call('ttl', 'future')
local llen = redis.call("LLEN", list)
local longest_live_till = current_ts + timeout
for i = 1, llen do
    local live_till = tonumber(redis.call("LPOP", KEYS[1]))
    if live_till > current_ts then
        redis.call("RPUSH", list, live_till)
    elseif live_till > longest_live_till then
        longest_live_till = live_till
    end
end
llen = redis.call("LLEN", list)
if llen < list_max_size then
    redis.call('RPUSH', list, timeout + current_ts)
    local ttl = tonumber(redis.call('TTL', list))
    if ttl == -1 then
        redis.call('EXPIRE', list, timeout)
    elseif ttl < longest_live_till - current_ts then
        redis.call('PERSIST', list)
        redis.call('EXPIRE', list, longest_live_till - current_ts)
    end
end
return llen
