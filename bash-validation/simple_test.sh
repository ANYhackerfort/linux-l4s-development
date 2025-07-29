#!/bin/bash

# === Variables ===
IPROUTE2_PATH="../tc/tc"
VETH_DEV="veth-s"
VETH_R_IP="172.20.1.2"
WATCH_INTERVAL=0.5
LOG_DIR="./tmp"

# === Setup Log Folder ===
mkdir -p "$LOG_DIR"

# === Reset qdisc stats ===
echo "🔁 Resetting qdisc stats..."
sudo ip netns exec ns_s $IPROUTE2_PATH qdisc del dev $VETH_DEV root 2>/dev/null
sudo ip netns exec ns_s $IPROUTE2_PATH qdisc add dev $VETH_DEV root handle 1: htb default 10
sudo ip netns exec ns_s $IPROUTE2_PATH class add dev $VETH_DEV parent 1: classid 1:10 htb rate 12mbit ceil 12mbit burst 15k
sudo ip netns exec ns_s $IPROUTE2_PATH qdisc add dev $VETH_DEV parent 1:10 handle 2: dualpi2 target 5ms step_thresh 1ms limit 200

# === Start iperf3 Server ===
echo "📡 Starting iperf3 server..."
sudo ip netns exec ns_r iperf3 -s -p 5202 &
SERVER_PID=$!

sleep 1

# === Start iperf3 Client ===
echo "🚀 Starting iperf3 client..."
sudo ip netns exec ns_s iperf3 -c 172.20.1.2 -p 5202 -t 30 -C prague &

echo "📥 Logging TCP socket info..."
(
  timeout 32s bash -c '
    while sleep 0.5; do
      {
        echo "------ $(date) ------"
        sudo ip netns exec ns_s ss -tin dst 172.20.1.2
      } >> ./tmp/ss.log
    done
  '
) & SS_PID=$!
echo "📊 Logging qdisc stats..."

(
  timeout 32s bash -c '
    while sleep 0.5; do
      {
        echo "------ $(date) ------"
        sudo ip netns exec ns_s ../tc/tc -s qdisc show dev veth-s
      } >> ./tmp/qdisc.log
    done
  '
) & QDISC_PID=$!

# === Wait and Cleanup ===
sleep 32
kill $SS_PID $QDISC_PID $SERVER_PID
sudo kill iperf3
echo "✅ Logs saved to $LOG_DIR"
