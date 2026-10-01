#!/bin/bash
# firewall-01 grader
source /opt/linux-labs/lib/grading.sh

grade_begin firewall-01

criterion "The firewalld service is running" systemctl is-active --quiet firewalld
criterion "Service http is allowed in the public zone" \
	firewall-cmd --zone=public --query-service=http
criterion "Port 8080/tcp is open in the public zone" \
	firewall-cmd --zone=public --query-port=8080/tcp
grade_end
