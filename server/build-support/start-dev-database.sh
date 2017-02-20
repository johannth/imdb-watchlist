set -e

CURRENT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

REDIS_VERSION=3.0.7

docker pull redis:$REDIS_VERSION
docker run -p 6379:6379 --name redis -v $CURRENT_DIR/.data:/data -d redis:$REDIS_VERSION redis-server --appendonly yes 
