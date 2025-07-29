import re
import matplotlib.pyplot as plt

log_file = "../tmp/qdisc.log"
time_stamps = []
dequeued_pkts = []

with open(log_file) as f:
    lines = f.readlines()

current_time = None
prev_sent = None
for line in lines:
    # Match timestamp lines
    ts_match = re.match(r"------ (.+) ------", line)
    if ts_match:
        current_time = ts_match.group(1)
    # Match cumulative sent packets lines
    sent_match = re.search(r"Sent \d+ bytes (\d+) pkt", line)
    if sent_match and current_time:
        sent = int(sent_match.group(1))
        if prev_sent is not None:
            dequeued_pkts.append(sent - prev_sent)
            time_stamps.append(current_time)
        prev_sent = sent

plt.figure(figsize=(12, 6))
plt.plot(dequeued_pkts, marker='o')
plt.title("Packets Dequeued Per Time Frame")
plt.xlabel("Time Frame")
plt.ylabel("Packets Dequeued")
plt.grid(True)