set -e

REDIS_VERSION=3.0.7

docker pull redis:$REDIS_VERSION
docker run -p 6379:6379 --name redis -d redis:$REDIS_VERSION
