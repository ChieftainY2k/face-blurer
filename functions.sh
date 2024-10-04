log_message() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] $@"
}

function countdown_seconds()
{
  local count=$1
  while [ $count -gt 0 ]; do
    echo -ne " $count"
    sleep 1
    count=$((count - 1))
  done
  echo ""
}

