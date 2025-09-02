# OMana

Redis-cli pet project.

# How to test it out

```
$ mix run --no-halt
```

in another session, run redis-cli:

```
redis-cli -p 6380
127.0.0.1:6380> PING
PONG
127.0.0.1:6380> SET a 1
OK
127.0.0.1:6380> GET a
"1"
127.0.0.1:6380> INCR a
(error) ERR value is not an integer or out of range
127.0.0.1:6380> INCR n
(integer) 1
127.0.0.1:6380> EXPIRE n 5
(integer) 1
127.0.0.1:6380> TTL n
(integer) 5
```
