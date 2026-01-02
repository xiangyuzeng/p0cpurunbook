# Standard Operation Runbook: Pod CPU High Usage Alert

# 标准运维手册：Pod CPU 高使用率告警

---

## Document Information | 文档信息

| Field | Value |
|-------|-------|
| **Runbook ID** | RB-K8S-CPU-001 |
| **Version** | 1.0 |
| **Last Updated** | 2026-01-02 |
| **Owner** | DevOps Team |
| **Review Cycle** | Quarterly |

---

## Table of Contents | 目录

1. [Alert Overview | 告警概述](#1-alert-overview--告警概述)
2. [Alert Metadata | 告警元数据](#2-alert-metadata--告警元数据)
3. [Initial Triage Checklist | 初始分诊清单](#3-initial-triage-checklist--初始分诊清单)
4. [Diagnostic Commands | 诊断命令](#4-diagnostic-commands--诊断命令)
5. [Root Cause Analysis Guide | 根因分析指南](#5-root-cause-analysis-guide--根因分析指南)
6. [Remediation Procedures | 修复流程](#6-remediation-procedures--修复流程)
7. [AWS-Specific Actions | AWS 特定操作](#7-aws-specific-actions--aws-特定操作)
8. [Grafana Dashboard Usage | Grafana 仪表板使用](#8-grafana-dashboard-usage--grafana-仪表板使用)
9. [Escalation Matrix | 升级矩阵](#9-escalation-matrix--升级矩阵)
10. [Communication Templates | 沟通模板](#10-communication-templates--沟通模板)
11. [Post-Incident Actions | 事后处理](#11-post-incident-actions--事后处理)
12. [Related Alerts | 相关告警](#12-related-alerts--相关告警)
13. [Historical Context | 历史背景](#13-historical-context--历史背景)
14. [Prevention Recommendations | 预防建议](#14-prevention-recommendations--预防建议)

---

## 1. Alert Overview | 告警概述

### Alert Name | 告警名称
- **Chinese**: 【pod-cpu-兜底】P0 CPU使用率连续3分钟大于85%
- **English**: [Pod-CPU-Fallback] P0 CPU Usage Exceeds 85% for 3 Consecutive Minutes

### Severity Level and SLA | 严重级别与SLA

| Severity | Response Time | Resolution Target | Business Impact |
|----------|---------------|-------------------|-----------------|
| **P0 - Critical** | **< 5 minutes** | **< 30 minutes** | Service degradation or outage possible |

### What This Alert Monitors | 监控内容

This alert monitors **real-time CPU utilization** of Kubernetes pods across all business-critical namespaces. The PromQL query:

**In Plain Language:**
1. **Calculates CPU usage percentage** for each pod by comparing actual CPU consumption (`container_cpu_usage_seconds_total`) against allocated CPU quota (`container_spec_cpu_quota`)
2. **Enriches data** with pod metadata (application name, pod IP) from `kube_pod_cust_labels`
3. **Filters out** system namespaces and specific excluded applications
4. **Triggers** when usage exceeds 85% for 3 consecutive minutes

**Formula Breakdown:**
```
CPU Usage % = (Actual CPU Usage Rate / CPU Quota) × 100
Alert fires when: CPU Usage % > 85% for 3 minutes
```

### Why This Alert Matters | 告警重要性

| Impact Area | Description |
|-------------|-------------|
| **Service Latency** | High CPU causes increased response times, affecting user experience |
| **Request Failures** | CPU throttling leads to timeouts and failed requests |
| **Cascade Failures** | Overloaded pods can trigger downstream service failures |
| **Customer Impact** | Direct impact on Luckin Coffee app and ordering systems |
| **Revenue Loss** | Order processing delays during peak hours affect sales |

### Excluded Resources | 排除的资源

| Exclusion Type | Values | Reason |
|----------------|--------|--------|
| **Namespaces** | `default`, `efk-log`, `kube-system`, `lcp-canary-system`, `lcp-notify-system`, `monitor`, `tcr-assistant-system`, `chaos-testing` | System/infrastructure namespaces with different SLAs |
| **Applications** | `icdpactivityengine`, `icdprealtimeusergroupengine` | Known high-CPU workloads with separate monitoring |
| **Pods** | `dify-*` | AI/ML workloads with expected high CPU usage |

---

## 2. Alert Metadata | 告警元数据

### Alert Configuration | 告警配置

| Parameter | Value |
|-----------|-------|
| **Alert ID** | `pod-cpu-p0-high-usage` |
| **Severity** | P0 (Critical) |
| **Threshold** | > 85% CPU utilization |
| **Duration** | 3 minutes continuous |
| **Evaluation Interval** | 1 minute |
| **Monitoring System** | iZeus / Prometheus |
| **Environment** | US Production (美国-生产) |

### Notification Channels | 通知渠道

| Channel | Enabled | Target |
|---------|---------|--------|
| Email | Yes | devops-alerts@luckincoffee.com |
| SMS | Yes | On-call engineer |
| Enterprise WeChat (企业微信) | Yes | DevOps Alert Group |
| Recovery Notification | Yes | All channels |

### Raw PromQL Query | 原始 PromQL 查询

```promql
label_replace(
  (
    (
      sum(rate(container_cpu_usage_seconds_total{container!="POD",container!="",pod!~"dify-*"}[1m])) by(pod,cluster)
      /
      sum(container_spec_cpu_quota{container!="POD",container!=""} / 100000) by(pod,cluster)
    ) * 100
    * on(pod) group_left(label_appName,pod_ip) kube_pod_cust_labels{
      namespace!~"default|efk-log|kube-system|lcp-canary-system|lcp-notify-system|monitor|tcr-assistant-system|chaos-testing",
      label_appName!~"icdpactivityengine|icdprealtimeusergroupengine"
    }
  ),
  "service","$1","label_appName","(.+)"
) > 85
```

### Alert Variables | 告警变量

| Variable | Description | Example Value |
|----------|-------------|---------------|
| `{{.Labels.pod}}` | Pod name | `isalesorder-5d8f9c7b6-x2k9j` |
| `{{.Labels.pod_ip}}` | Pod IP address | `10.238.14.105` |
| `{{.Labels.label_appName}}` | Application/Service name | `isalesorder` |
| `{{.Labels.cluster}}` | Cluster name | `luckyus-prod` |
| `{{.Labels.node}}` | Node hostname | `ip-10-238-14-104.ec2.internal` |
| `{{.Value}}` | Current CPU usage % | `92.5` |

---

## 3. Initial Triage Checklist | 初始分诊清单 (First 5 Minutes)

### Immediate Actions Checklist | 立即行动清单

```
□ Step 1: Acknowledge the alert in Enterprise WeChat
□ Step 2: Open Grafana dashboard for the affected pod
□ Step 3: Verify alert is not a false positive
□ Step 4: Check if multiple pods/services are affected
□ Step 5: Assess business impact
□ Step 6: Start incident documentation
```

### Quick Verification Commands | 快速验证命令

```bash
# Set environment variables from alert
export POD_NAME="<pod_name_from_alert>"
export NAMESPACE="<namespace>"  # Determine from pod naming convention
export NODE_NAME="<node_from_alert>"
export APP_NAME="<label_appName_from_alert>"

# 1. Verify pod exists and check status
kubectl get pod ${POD_NAME} -n ${NAMESPACE} -o wide

# 2. Check current CPU usage (real-time)
kubectl top pod ${POD_NAME} -n ${NAMESPACE}

# 3. Quick node health check
kubectl top node ${NODE_NAME}

# 4. Check if pod is being throttled
kubectl get pod ${POD_NAME} -n ${NAMESPACE} -o jsonpath='{.status.containerStatuses[*].state}'
```

### False Positive Identification | 误报识别

Check if this is a false positive:

| Condition | How to Verify | Action if True |
|-----------|---------------|----------------|
| **Metric collection lag** | Compare Grafana time with current time | Wait 1-2 minutes, re-check |
| **Pod already terminated** | `kubectl get pod` returns NotFound | Close alert as resolved |
| **Planned deployment in progress** | Check deployment status | Monitor and wait for completion |
| **Load test in progress** | Check with QA team | Document and close if expected |
| **Alert threshold temporarily breached** | CPU dropped below 85% | Monitor for 5 more minutes |

### Quick Health Check Script | 快速健康检查脚本

```bash
#!/bin/bash
# Quick health check script for CPU alert triage
# Usage: ./cpu_alert_triage.sh <pod_name> <namespace>

POD_NAME=$1
NAMESPACE=$2

echo "========== CPU Alert Triage for ${POD_NAME} =========="
echo ""
echo "1. Pod Status:"
kubectl get pod ${POD_NAME} -n ${NAMESPACE} -o wide
echo ""
echo "2. Current Resource Usage:"
kubectl top pod ${POD_NAME} -n ${NAMESPACE}
echo ""
echo "3. Pod Events (last 10):"
kubectl get events -n ${NAMESPACE} --field-selector involvedObject.name=${POD_NAME} --sort-by='.lastTimestamp' | tail -10
echo ""
echo "4. Container Resource Limits:"
kubectl get pod ${POD_NAME} -n ${NAMESPACE} -o jsonpath='{range .spec.containers[*]}Container: {.name}{"\n"}  CPU Request: {.resources.requests.cpu}{"\n"}  CPU Limit: {.resources.limits.cpu}{"\n"}{end}'
echo ""
echo "5. Pod Restart Count:"
kubectl get pod ${POD_NAME} -n ${NAMESPACE} -o jsonpath='{range .status.containerStatuses[*]}{.name}: {.restartCount} restarts{"\n"}{end}'
```

---

## 4. Diagnostic Commands | 诊断命令

### Pod-Level Diagnostics | Pod 级别诊断

```bash
# ============================================
# POD CPU DIAGNOSTICS
# ============================================

# Check real-time CPU usage for the pod
kubectl top pod ${POD_NAME} -n ${NAMESPACE} --containers

# Get detailed pod information
kubectl describe pod ${POD_NAME} -n ${NAMESPACE}

# Check resource requests and limits
kubectl get pod ${POD_NAME} -n ${NAMESPACE} -o jsonpath='
CPU Requests: {.spec.containers[0].resources.requests.cpu}
CPU Limits: {.spec.containers[0].resources.limits.cpu}
Memory Requests: {.spec.containers[0].resources.requests.memory}
Memory Limits: {.spec.containers[0].resources.limits.memory}
'

# Check CPU throttling metrics (if available)
kubectl exec -it ${POD_NAME} -n ${NAMESPACE} -- cat /sys/fs/cgroup/cpu/cpu.stat 2>/dev/null || echo "Cannot access cgroup stats"

# Check process CPU usage inside container
kubectl exec -it ${POD_NAME} -n ${NAMESPACE} -- top -bn1 | head -20

# Check for runaway processes
kubectl exec -it ${POD_NAME} -n ${NAMESPACE} -- ps aux --sort=-%cpu | head -10
```

### Application Logs | 应用日志

```bash
# ============================================
# APPLICATION LOG ANALYSIS
# ============================================

# Get recent logs (last 100 lines)
kubectl logs ${POD_NAME} -n ${NAMESPACE} --tail=100

# Get logs from the last 5 minutes
kubectl logs ${POD_NAME} -n ${NAMESPACE} --since=5m

# Follow logs in real-time (use Ctrl+C to exit)
kubectl logs -f ${POD_NAME} -n ${NAMESPACE}

# Check for error patterns
kubectl logs ${POD_NAME} -n ${NAMESPACE} --since=10m | grep -iE "(error|exception|timeout|oom|killed)"

# Check for high request volume
kubectl logs ${POD_NAME} -n ${NAMESPACE} --since=5m | grep -c "request" || echo "No request logs found"

# Get logs from previous container instance (if restarted)
kubectl logs ${POD_NAME} -n ${NAMESPACE} --previous --tail=50 2>/dev/null || echo "No previous container logs"
```

### Node-Level Diagnostics | 节点级别诊断

```bash
# ============================================
# NODE DIAGNOSTICS
# ============================================

# Check node resource usage
kubectl top node ${NODE_NAME}

# Get node details
kubectl describe node ${NODE_NAME}

# Check all pods on the affected node
kubectl get pods --all-namespaces -o wide --field-selector spec.nodeName=${NODE_NAME}

# Check node conditions
kubectl get node ${NODE_NAME} -o jsonpath='{range .status.conditions[*]}{.type}: {.status}{"\n"}{end}'

# Check node allocatable resources
kubectl get node ${NODE_NAME} -o jsonpath='
Allocatable CPU: {.status.allocatable.cpu}
Allocatable Memory: {.status.allocatable.memory}
Capacity CPU: {.status.capacity.cpu}
Capacity Memory: {.status.capacity.memory}
'
```

### Deployment & HPA Status | Deployment 和 HPA 状态

```bash
# ============================================
# DEPLOYMENT & SCALING DIAGNOSTICS
# ============================================

# Get deployment name from pod
DEPLOYMENT_NAME=$(kubectl get pod ${POD_NAME} -n ${NAMESPACE} -o jsonpath='{.metadata.ownerReferences[?(@.kind=="ReplicaSet")].name}' | sed 's/-[a-z0-9]*$//')

# Check deployment status
kubectl get deployment ${DEPLOYMENT_NAME} -n ${NAMESPACE}

# Check deployment details
kubectl describe deployment ${DEPLOYMENT_NAME} -n ${NAMESPACE}

# Check HPA status (if exists)
kubectl get hpa -n ${NAMESPACE} | grep ${DEPLOYMENT_NAME} || echo "No HPA found for this deployment"

# Get HPA details
kubectl describe hpa ${DEPLOYMENT_NAME} -n ${NAMESPACE} 2>/dev/null || echo "HPA not configured"

# Check replica set status
kubectl get rs -n ${NAMESPACE} | grep ${DEPLOYMENT_NAME}

# Check recent deployment events
kubectl get events -n ${NAMESPACE} --field-selector involvedObject.kind=Deployment,involvedObject.name=${DEPLOYMENT_NAME} --sort-by='.lastTimestamp' | tail -10
```

### Network & External Dependencies | 网络和外部依赖

```bash
# ============================================
# NETWORK & DEPENDENCY DIAGNOSTICS
# ============================================

# Check service endpoints
kubectl get endpoints -n ${NAMESPACE} | grep ${APP_NAME}

# Check if pod can reach external services
kubectl exec -it ${POD_NAME} -n ${NAMESPACE} -- curl -s -o /dev/null -w "%{http_code}" http://localhost:8080/health 2>/dev/null || echo "Health endpoint not available"

# Check DNS resolution
kubectl exec -it ${POD_NAME} -n ${NAMESPACE} -- nslookup kubernetes.default 2>/dev/null || echo "DNS check not available"

# Check network policies affecting the pod
kubectl get networkpolicies -n ${NAMESPACE}
```

### Prometheus Queries for Investigation | Prometheus 查询

```promql
# Current CPU usage for specific pod
sum(rate(container_cpu_usage_seconds_total{pod="<POD_NAME>",container!="POD"}[5m])) by (container)

# CPU usage history (last 1 hour)
sum(rate(container_cpu_usage_seconds_total{pod="<POD_NAME>",container!="POD"}[5m])) by (container)

# CPU throttling for the pod
rate(container_cpu_cfs_throttled_seconds_total{pod="<POD_NAME>"}[5m])

# All pods with high CPU in the same namespace
(sum(rate(container_cpu_usage_seconds_total{namespace="<NAMESPACE>",container!="POD"}[5m])) by (pod) / sum(container_spec_cpu_quota{namespace="<NAMESPACE>",container!="POD"} / 100000) by (pod)) * 100 > 80

# Memory usage correlation (high memory can cause CPU issues)
container_memory_usage_bytes{pod="<POD_NAME>",container!="POD"} / container_spec_memory_limit_bytes{pod="<POD_NAME>",container!="POD"} * 100

# Request rate to the service
sum(rate(http_server_requests_seconds_count{application="<APP_NAME>"}[5m]))
```

---

## 5. Root Cause Analysis Guide | 根因分析指南

### Decision Tree | 决策树

```
                    ┌─────────────────────────────┐
                    │   CPU > 85% Alert Fired     │
                    └─────────────┬───────────────┘
                                  │
                    ┌─────────────▼───────────────┐
                    │  Is it affecting multiple   │
                    │  pods/services?             │
                    └─────────────┬───────────────┘
                          │               │
                         YES              NO
                          │               │
            ┌─────────────▼─────┐   ┌────▼────────────────┐
            │ Check for:        │   │ Single Pod Issue    │
            │ - Traffic spike   │   │ Check for:          │
            │ - Node issue      │   │ - Memory leak       │
            │ - Deployment      │   │ - Infinite loop     │
            │ - DDoS attack     │   │ - Blocking operation│
            └───────────────────┘   └─────────────────────┘
```

### Common Root Causes | 常见根因

#### 1. Traffic Spike / Unexpected Load | 流量突增
**Symptoms:**
- Multiple pods showing high CPU simultaneously
- Increased request rate in metrics
- Higher than normal active connections

**Verification:**
```bash
# Check request rate in Prometheus
# Query: sum(rate(http_server_requests_seconds_count{application="<APP_NAME>"}[5m]))

# Check ingress logs for traffic patterns
kubectl logs -n ingress-nginx -l app.kubernetes.io/name=ingress-nginx --tail=100 | grep ${APP_NAME}
```

#### 2. Memory Leak Causing CPU Thrashing | 内存泄漏导致CPU抖动
**Symptoms:**
- Gradual CPU increase over time
- High memory usage approaching limits
- Frequent garbage collection (for JVM apps)

**Verification:**
```bash
# Check memory usage
kubectl top pod ${POD_NAME} -n ${NAMESPACE}

# Check for OOM events
kubectl get events -n ${NAMESPACE} | grep -i oom

# For JVM applications, check GC activity
kubectl logs ${POD_NAME} -n ${NAMESPACE} | grep -i "gc\|garbage"
```

#### 3. Inefficient Code / Infinite Loops | 低效代码/死循环
**Symptoms:**
- Single pod affected
- CPU stuck at near 100%
- No increase in request completion rate

**Verification:**
```bash
# Check if requests are completing
kubectl logs ${POD_NAME} -n ${NAMESPACE} --since=5m | grep -c "completed\|response"

# Check thread dump (Java applications)
kubectl exec -it ${POD_NAME} -n ${NAMESPACE} -- jstack 1 2>/dev/null | head -100
```

#### 4. Resource Limits Too Low | 资源限制过低
**Symptoms:**
- Pod consistently at high CPU
- Frequent CPU throttling
- Good performance after scaling

**Verification:**
```bash
# Check current limits
kubectl get pod ${POD_NAME} -n ${NAMESPACE} -o jsonpath='{.spec.containers[0].resources}'

# Check throttling metrics in Prometheus
# Query: rate(container_cpu_cfs_throttled_seconds_total{pod="<POD_NAME>"}[5m])
```

#### 5. Node Resource Contention | 节点资源争用
**Symptoms:**
- Multiple pods on same node affected
- Node showing high CPU usage
- Other pods on node also slow

**Verification:**
```bash
# Check all pods on the node
kubectl top pods --all-namespaces --field-selector spec.nodeName=${NODE_NAME}

# Check node-level CPU
kubectl top node ${NODE_NAME}
```

#### 6. External Dependency Issues | 外部依赖问题
**Symptoms:**
- Requests timing out
- High number of retries
- Connection pool exhaustion

**Verification:**
```bash
# Check for timeout errors
kubectl logs ${POD_NAME} -n ${NAMESPACE} --since=10m | grep -iE "timeout|connection refused|socket"

# Check database connection status
kubectl exec -it ${POD_NAME} -n ${NAMESPACE} -- netstat -an | grep ESTABLISHED | wc -l
```

#### 7. Database Query Issues | 数据库查询问题
**Symptoms:**
- Slow response times
- Database connections building up
- Correlated with specific operations

**Verification:**
```bash
# Check application logs for slow queries
kubectl logs ${POD_NAME} -n ${NAMESPACE} --since=10m | grep -iE "slow|query|sql" | tail -20
```

### Root Cause Summary Matrix | 根因总结矩阵

| Root Cause | Single Pod | Multiple Pods | High Memory | Gradual Onset | Sudden Onset |
|------------|:----------:|:-------------:|:-----------:|:-------------:|:------------:|
| Traffic Spike | - | ✓ | - | - | ✓ |
| Memory Leak | ✓ | - | ✓ | ✓ | - |
| Code Issue | ✓ | - | - | ✓ | ✓ |
| Low Limits | ✓ | - | - | - | ✓ |
| Node Contention | - | ✓ | - | ✓ | ✓ |
| External Deps | ✓ | ✓ | - | - | ✓ |
| DB Issues | ✓ | ✓ | - | - | ✓ |

---

## 6. Remediation Procedures | 修复流程

### 6.1 Horizontal Scaling (HPA Adjustment) | 水平扩展

**When to use:** Traffic spike, load increase, multiple pods needed

```bash
# Check current HPA status
kubectl get hpa ${DEPLOYMENT_NAME} -n ${NAMESPACE}

# Option A: Manually scale deployment
kubectl scale deployment ${DEPLOYMENT_NAME} -n ${NAMESPACE} --replicas=<NEW_COUNT>

# Option B: Adjust HPA minimum replicas
kubectl patch hpa ${DEPLOYMENT_NAME} -n ${NAMESPACE} -p '{"spec":{"minReplicas":<NEW_MIN>}}'

# Option C: Create temporary HPA if not exists
kubectl autoscale deployment ${DEPLOYMENT_NAME} -n ${NAMESPACE} --min=3 --max=10 --cpu-percent=70

# Verify scaling
kubectl get pods -n ${NAMESPACE} -l app=${APP_NAME} -w
```

**Expected Outcome:** New pods created, load distributed, CPU per pod decreases
**Verification:** `kubectl top pods -n ${NAMESPACE} -l app=${APP_NAME}`

### 6.2 Vertical Scaling (Resource Limit Increase) | 垂直扩展

**When to use:** Single pod consistently at limit, resource limits too low

> **WARNING**: This will cause a rolling restart of pods

```bash
# Check current limits
kubectl get deployment ${DEPLOYMENT_NAME} -n ${NAMESPACE} -o jsonpath='{.spec.template.spec.containers[0].resources}'

# Update CPU limits (example: increase from 1 to 2 cores)
kubectl patch deployment ${DEPLOYMENT_NAME} -n ${NAMESPACE} -p '
{
  "spec": {
    "template": {
      "spec": {
        "containers": [{
          "name": "<CONTAINER_NAME>",
          "resources": {
            "requests": {"cpu": "500m", "memory": "512Mi"},
            "limits": {"cpu": "2000m", "memory": "1Gi"}
          }
        }]
      }
    }
  }
}'

# Monitor rollout
kubectl rollout status deployment ${DEPLOYMENT_NAME} -n ${NAMESPACE}
```

**Expected Outcome:** Pods restart with new limits, CPU percentage drops
**Verification:** `kubectl describe pod <NEW_POD> -n ${NAMESPACE} | grep -A5 "Limits"`

### 6.3 Rolling Restart | 滚动重启

**When to use:** Memory leak suspected, stuck processes, quick recovery needed

```bash
# Trigger rolling restart
kubectl rollout restart deployment ${DEPLOYMENT_NAME} -n ${NAMESPACE}

# Monitor the rollout
kubectl rollout status deployment ${DEPLOYMENT_NAME} -n ${NAMESPACE}

# Check new pods are healthy
kubectl get pods -n ${NAMESPACE} -l app=${APP_NAME}

# Verify CPU after restart
kubectl top pods -n ${NAMESPACE} -l app=${APP_NAME}
```

**Expected Outcome:** All pods restart gracefully, fresh state
**Verification:** Check pod age and CPU usage

### 6.4 Traffic Shifting / Load Balancing | 流量切换

**When to use:** Need to reduce load on specific pods, during investigation

```bash
# Remove pod from service (add label to exclude)
kubectl label pod ${POD_NAME} -n ${NAMESPACE} serving=false --overwrite

# Check service endpoints
kubectl get endpoints -n ${NAMESPACE} | grep ${APP_NAME}

# Restore pod to service
kubectl label pod ${POD_NAME} -n ${NAMESPACE} serving=true --overwrite
```

### 6.5 Emergency Pod Termination | 紧急Pod终止

> **WARNING**: Use only when pod is unrecoverable and affecting other services

```bash
# Force delete the problematic pod (will be recreated by deployment)
kubectl delete pod ${POD_NAME} -n ${NAMESPACE}

# If pod is stuck terminating, force delete
kubectl delete pod ${POD_NAME} -n ${NAMESPACE} --grace-period=0 --force

# Verify new pod is created
kubectl get pods -n ${NAMESPACE} -l app=${APP_NAME}
```

### 6.6 Node Drain (For Node Issues) | 节点排空

**When to use:** Node-level issues affecting multiple pods

> **WARNING**: This will evict all pods from the node

```bash
# Cordon the node (prevent new pods)
kubectl cordon ${NODE_NAME}

# Drain the node (evict pods gracefully)
kubectl drain ${NODE_NAME} --ignore-daemonsets --delete-emptydir-data

# After issue resolved, uncordon
kubectl uncordon ${NODE_NAME}
```

### Remediation Quick Reference | 修复快速参考

| Scenario | Action | Command |
|----------|--------|---------|
| Quick scale | Add 2 more pods | `kubectl scale deployment ${DEPLOYMENT_NAME} -n ${NAMESPACE} --replicas=$((CURRENT+2))` |
| Restart pods | Rolling restart | `kubectl rollout restart deployment ${DEPLOYMENT_NAME} -n ${NAMESPACE}` |
| Isolate pod | Remove from service | `kubectl label pod ${POD_NAME} -n ${NAMESPACE} serving=false` |
| Kill stuck pod | Force delete | `kubectl delete pod ${POD_NAME} -n ${NAMESPACE} --force` |
| Node issue | Drain node | `kubectl drain ${NODE_NAME} --ignore-daemonsets` |

---

## 7. AWS-Specific Actions | AWS 特定操作

### 7.1 EC2 Instance Health Checks | EC2 实例健康检查

```bash
# Get EC2 instance ID from node name
INSTANCE_ID=$(aws ec2 describe-instances \
  --filters "Name=private-dns-name,Values=${NODE_NAME}" \
  --query "Reservations[0].Instances[0].InstanceId" \
  --output text)

# Check instance status
aws ec2 describe-instance-status \
  --instance-ids ${INSTANCE_ID} \
  --query "InstanceStatuses[0].{InstanceState:InstanceState.Name,SystemStatus:SystemStatus.Status,InstanceStatus:InstanceStatus.Status}"

# Check instance CPU utilization (CloudWatch)
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUUtilization \
  --dimensions Name=InstanceId,Value=${INSTANCE_ID} \
  --start-time $(date -u -d '30 minutes ago' +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 300 \
  --statistics Average

# Check instance credit balance (for burstable instances)
aws cloudwatch get-metric-statistics \
  --namespace AWS/EC2 \
  --metric-name CPUCreditBalance \
  --dimensions Name=InstanceId,Value=${INSTANCE_ID} \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 300 \
  --statistics Average
```

### 7.2 EKS Cluster Diagnostics | EKS 集群诊断

```bash
# Get EKS cluster name
CLUSTER_NAME="luckyus-prod"  # Replace with actual cluster name

# Check cluster status
aws eks describe-cluster --name ${CLUSTER_NAME} --query "cluster.status"

# Check node group status
aws eks list-nodegroups --cluster-name ${CLUSTER_NAME}

aws eks describe-nodegroup \
  --cluster-name ${CLUSTER_NAME} \
  --nodegroup-name <NODEGROUP_NAME> \
  --query "nodegroup.{Status:status,DesiredSize:scalingConfig.desiredSize,CurrentSize:scalingConfig.desiredSize}"

# Check for cluster issues
aws eks describe-cluster --name ${CLUSTER_NAME} --query "cluster.health"
```

### 7.3 CloudWatch Metrics to Review | CloudWatch 指标查看

**Key Metrics:**
- `ContainerInsights/pod_cpu_utilization`
- `ContainerInsights/pod_memory_utilization`
- `ContainerInsights/pod_network_rx_bytes`
- `ContainerInsights/pod_network_tx_bytes`

```bash
# Get Container Insights CPU metrics
aws cloudwatch get-metric-statistics \
  --namespace ContainerInsights \
  --metric-name pod_cpu_utilization \
  --dimensions Name=ClusterName,Value=${CLUSTER_NAME} Name=PodName,Value=${POD_NAME} Name=Namespace,Value=${NAMESPACE} \
  --start-time $(date -u -d '1 hour ago' +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 60 \
  --statistics Average Maximum

# Check node-level metrics
aws cloudwatch get-metric-statistics \
  --namespace ContainerInsights \
  --metric-name node_cpu_utilization \
  --dimensions Name=ClusterName,Value=${CLUSTER_NAME} Name=NodeName,Value=${NODE_NAME} \
  --start-time $(date -u -d '30 minutes ago' +%Y-%m-%dT%H:%M:%SZ) \
  --end-time $(date -u +%Y-%m-%dT%H:%M:%SZ) \
  --period 60 \
  --statistics Average
```

### 7.4 Auto Scaling Group Considerations | 自动扩展组注意事项

```bash
# Find ASG for the node group
ASG_NAME=$(aws autoscaling describe-auto-scaling-groups \
  --query "AutoScalingGroups[?contains(Tags[?Key=='eks:nodegroup-name'].Value, '<NODEGROUP_NAME>')].AutoScalingGroupName" \
  --output text)

# Check ASG status
aws autoscaling describe-auto-scaling-groups \
  --auto-scaling-group-names ${ASG_NAME} \
  --query "AutoScalingGroups[0].{Desired:DesiredCapacity,Min:MinSize,Max:MaxSize,Current:length(Instances)}"

# Check scaling activities
aws autoscaling describe-scaling-activities \
  --auto-scaling-group-name ${ASG_NAME} \
  --max-items 5

# Manually increase capacity if needed
aws autoscaling set-desired-capacity \
  --auto-scaling-group-name ${ASG_NAME} \
  --desired-capacity <NEW_CAPACITY>
```

### 7.5 AWS Support Case | AWS 支持案例

If infrastructure-level issues are suspected:

```bash
# Create support case (requires Business/Enterprise support)
aws support create-case \
  --subject "High CPU on EKS node ${NODE_NAME}" \
  --service-code "amazon-elastic-kubernetes-service" \
  --severity-code "high" \
  --category-code "performance" \
  --communication-body "We are experiencing high CPU utilization on EKS node ${NODE_NAME} in cluster ${CLUSTER_NAME}. Instance ID: ${INSTANCE_ID}. Please investigate."
```

---

## 8. Grafana Dashboard Usage | Grafana 仪表板使用

### Primary Dashboard | 主仪表板

**Dashboard URL:** https://jumbgrafana.luckincoffee.us/grafana/d/mESvEBOnk/lucky-podzhu-ji-wei-du-jian-kong-yi-biao-pan

### Key Panels to Review | 关键面板

| Panel Name | Purpose | What to Look For |
|------------|---------|------------------|
| **Pod CPU Usage** | Shows CPU % per pod | Identify which pods are high |
| **CPU Throttling** | Shows CPU throttling rate | High throttling = resource limits too low |
| **Memory Usage** | Correlate with CPU issues | High memory can cause CPU issues |
| **Request Rate** | Incoming traffic | Spike correlates with CPU spike? |
| **Response Time** | Application performance | Degraded performance = impact confirmed |
| **Pod Restarts** | Stability indicator | Frequent restarts = underlying issue |

### Recommended Time Ranges | 推荐时间范围

| Scenario | Time Range | Reason |
|----------|------------|--------|
| **Initial Investigation** | Last 15 minutes | Focus on current state |
| **Trend Analysis** | Last 1 hour | See if issue is building up |
| **Pattern Recognition** | Last 24 hours | Identify daily patterns |
| **Comparison** | Same time yesterday | Compare with normal baseline |

### Grafana Query Examples | Grafana 查询示例

```promql
# Add these to ad-hoc exploration in Grafana

# CPU usage for specific app
sum(rate(container_cpu_usage_seconds_total{pod=~"${APP_NAME}-.*",container!="POD"}[5m])) by (pod)

# CPU limit utilization percentage
(sum(rate(container_cpu_usage_seconds_total{pod=~"${APP_NAME}-.*",container!="POD"}[5m])) by (pod) / sum(container_spec_cpu_quota{pod=~"${APP_NAME}-.*"} / 100000) by (pod)) * 100

# Compare with other pods in namespace
topk(10, sum(rate(container_cpu_usage_seconds_total{namespace="${NAMESPACE}",container!="POD"}[5m])) by (pod))
```

### Creating Alert-Specific View | 创建告警特定视图

1. Open Grafana Dashboard
2. Add variables filter for:
   - `pod`: Set to `{{.Labels.pod}}`
   - `namespace`: Set to pod's namespace
   - `node`: Set to `{{.Labels.node}}`
3. Set time range to "Last 30 minutes"
4. Enable auto-refresh (10s)

### Dashboard Link with Parameters | 带参数的仪表板链接

```
https://jumbgrafana.luckincoffee.us/grafana/d/mESvEBOnk/lucky-podzhu-ji-wei-du-jian-kong-yi-biao-pan?var-pod=${POD_NAME}&var-namespace=${NAMESPACE}&from=now-30m&to=now&refresh=10s
```

---

## 9. Escalation Matrix | 升级矩阵

### Time-Based Escalation | 基于时间的升级

| Time Elapsed | Condition | Action | Contact | Communication |
|--------------|-----------|--------|---------|---------------|
| **0-5 min** | Alert fires | Initial triage | On-call Engineer | Acknowledge in WeChat |
| **5-15 min** | Unresolved, investigating | Continue diagnosis | Team Lead (backup) | Status update to team |
| **15-30 min** | Impact confirmed | Engage team lead | Engineering Manager | Incident channel created |
| **30-60 min** | Service degradation | Major incident | Incident Commander | Stakeholder notification |
| **60+ min** | Extended outage | Executive escalation | VP Engineering | Customer communication |

### Severity-Based Escalation | 基于严重性的升级

| Impact Level | Description | Escalation Path |
|--------------|-------------|-----------------|
| **Low** | Single pod, no user impact | On-call resolves |
| **Medium** | Multiple pods, minor degradation | Team lead involved |
| **High** | Service degradation, some users affected | Engineering manager + Incident response |
| **Critical** | Service outage, major user impact | Full incident team + Executive notification |

### Contact Information | 联系信息

| Role | Primary Contact | Backup Contact | Escalation Method |
|------|-----------------|----------------|-------------------|
| On-call Engineer | Refer to PagerDuty/OpsGenie schedule | - | Auto-alert |
| Team Lead | [Team Lead Name] | [Backup Name] | Phone call |
| Engineering Manager | [EM Name] | [Backup EM] | Phone call |
| Incident Commander | [IC Rotation] | - | Incident bridge |
| VP Engineering | [VP Name] | - | Phone (critical only) |

### Escalation Decision Tree | 升级决策树

```
Is service impacting users?
    │
    ├── NO → Continue troubleshooting (On-call)
    │
    └── YES → Is it affecting >10% of requests?
                  │
                  ├── NO → Medium severity, engage Team Lead at 15 min
                  │
                  └── YES → Is revenue being lost?
                              │
                              ├── NO → High severity, engage EM at 15 min
                              │
                              └── YES → Critical, immediate executive escalation
```

---

## 10. Communication Templates | 沟通模板

### 10.1 Initial Acknowledgment (Chinese) | 初始确认

```
【告警确认】P0 CPU告警 - ${APP_NAME}

告警时间: ${ALERT_TIME}
影响服务: ${APP_NAME}
当前状态: 正在处理中
处理人员: ${ON_CALL_NAME}

告警详情:
- Pod名称: ${POD_NAME}
- CPU使用率: ${CPU_VALUE}%
- 所在节点: ${NODE_NAME}
- 集群: ${CLUSTER_NAME}

当前操作:
1. 已确认告警
2. 正在进行初步诊断
3. 预计5分钟内提供更新

如有紧急情况请电话联系: ${ON_CALL_PHONE}
```

### 10.2 Status Update (Bilingual) | 状态更新

```
【状态更新 / Status Update】P0 CPU Alert - ${APP_NAME}

时间 / Time: ${UPDATE_TIME}
状态 / Status: 调查中 / Investigating

发现 / Findings:
- 根因: ${ROOT_CAUSE_CN} / ${ROOT_CAUSE_EN}
- 影响范围: ${IMPACT_SCOPE_CN} / ${IMPACT_SCOPE_EN}

已执行操作 / Actions Taken:
1. ${ACTION_1}
2. ${ACTION_2}

下一步计划 / Next Steps:
1. ${NEXT_STEP_1}
2. ${NEXT_STEP_2}

预计恢复时间 / ETA: ${ETA}

如需升级请联系 / Escalation Contact: ${ESCALATION_CONTACT}
```

### 10.3 Resolution Message (Chinese) | 解决通知

```
【告警恢复】P0 CPU告警已解决 - ${APP_NAME}

恢复时间: ${RESOLUTION_TIME}
持续时间: ${DURATION}
处理人员: ${RESOLVER_NAME}

问题摘要:
- 根因: ${ROOT_CAUSE}
- 影响: ${IMPACT_SUMMARY}

解决方案:
${SOLUTION_DESCRIPTION}

后续行动:
□ 创建事后分析文档
□ 更新监控阈值 (如适用)
□ 创建改进工单

监控链接: ${GRAFANA_LINK}

感谢团队配合！
```

### 10.4 Post-Incident Summary | 事后总结

```
# P0 CPU Alert Incident Report
## 事件报告: P0 CPU告警

### Basic Information | 基本信息
- **Incident ID**: INC-${INCIDENT_ID}
- **Date/Time**: ${INCIDENT_DATE}
- **Duration**: ${DURATION}
- **Severity**: P0
- **Service**: ${APP_NAME}

### Timeline | 时间线
| Time | Event |
|------|-------|
| ${T0} | Alert triggered |
| ${T1} | Acknowledged by ${ON_CALL} |
| ${T2} | Root cause identified |
| ${T3} | Remediation applied |
| ${T4} | Service recovered |

### Root Cause | 根因
${ROOT_CAUSE_DETAILED}

### Impact | 影响
- Users affected: ${USER_COUNT}
- Failed requests: ${FAILED_REQUESTS}
- Revenue impact: ${REVENUE_IMPACT}

### Resolution | 解决方案
${RESOLUTION_DETAILED}

### Action Items | 后续行动
| Item | Owner | Due Date | Status |
|------|-------|----------|--------|
| ${ACTION_1} | ${OWNER_1} | ${DATE_1} | Open |
| ${ACTION_2} | ${OWNER_2} | ${DATE_2} | Open |

### Lessons Learned | 经验教训
${LESSONS_LEARNED}
```

### 10.5 Customer Communication (If Needed) | 客户沟通

```
Subject: Service Update - Luckin Coffee App

Dear Customers,

We experienced a brief service disruption on ${DATE} between ${START_TIME} and ${END_TIME} (US Eastern Time).

During this time, some users may have experienced:
- Slower app response times
- Delayed order confirmations

Our engineering team identified and resolved the issue. All services are now operating normally.

We apologize for any inconvenience caused.

Sincerely,
Luckin Coffee Technical Team

---

尊敬的客户：

我们在${DATE} ${START_TIME}至${END_TIME}（美东时间）期间遇到了短暂的服务中断。

在此期间，部分用户可能遇到：
- 应用响应变慢
- 订单确认延迟

我们的技术团队已识别并解决了该问题，所有服务现已恢复正常。

对于给您带来的不便，我们深表歉意。

瑞幸咖啡技术团队
```

---

## 11. Post-Incident Actions | 事后处理

### 11.1 Metrics to Document | 需记录的指标

```
Incident Documentation Checklist:

□ Peak CPU utilization: ____%
□ Duration of high CPU: ____ minutes
□ Number of pods affected: ____
□ Number of services affected: ____
□ Error rate during incident: ____%
□ P99 latency during incident: ____ ms
□ User-facing errors: ____
□ Failed transactions: ____
□ Time to detect (TTD): ____ minutes
□ Time to mitigate (TTM): ____ minutes
□ Time to resolve (TTR): ____ minutes
```

### 11.2 Post-Mortem Requirements (P0) | 事后分析要求

For P0 incidents, a post-mortem is **mandatory**. Complete within 5 business days.

**Post-Mortem Template Location:** [Internal Wiki Link]

**Required Sections:**
1. Executive Summary
2. Timeline of Events
3. Root Cause Analysis (5 Whys)
4. Impact Assessment
5. Detection & Response Analysis
6. Corrective Actions
7. Lessons Learned

**Review Meeting:**
- Schedule within 3 business days
- Attendees: On-call, Team Lead, EM, affected service owners
- Duration: 30-60 minutes

### 11.3 Follow-up Tickets | 后续工单

Create tickets in JIRA/Internal ticketing system:

| Ticket Type | Priority | Template |
|-------------|----------|----------|
| Bug Fix | P1 | If code issue found |
| Infrastructure | P2 | If capacity issue |
| Monitoring Improvement | P3 | Alert tuning needed |
| Documentation | P4 | Runbook updates |

**Ticket Template:**
```
Title: [POST-INC] ${SHORT_DESCRIPTION}
Labels: post-incident, cpu-alert, ${SERVICE_NAME}
Priority: ${PRIORITY}

Related Incident: INC-${INCIDENT_ID}

Description:
During incident INC-${INCIDENT_ID}, we identified the following improvement opportunity:

${DESCRIPTION}

Acceptance Criteria:
- [ ] ${CRITERIA_1}
- [ ] ${CRITERIA_2}

Due Date: ${DUE_DATE}
```

### 11.4 Capacity Planning Recommendations | 容量规划建议

After any CPU-related incident, evaluate:

```
Capacity Review Checklist:

Current State:
□ Current pod count: ____
□ Current CPU requests: ____ per pod
□ Current CPU limits: ____ per pod
□ Current HPA settings: min=____, max=____, target=____%

Recommendations:
□ Increase baseline replicas by ____%
□ Adjust CPU requests to ____
□ Adjust CPU limits to ____
□ Modify HPA target to ____%
□ Add node capacity: ____ nodes

Justification:
${CAPACITY_JUSTIFICATION}

Cost Impact:
- Additional monthly cost: $____
- ROI calculation: ${ROI_CALCULATION}
```

---

## 12. Related Alerts | 相关告警

### Alerts That May Fire Together | 可能同时触发的告警

| Alert Name | Relationship | Action |
|------------|--------------|--------|
| **Pod Memory High** | Memory pressure can cause CPU spikes | Check memory first |
| **Pod Restart Frequent** | OOM kills cause restarts | Check OOM events |
| **Node CPU High** | Node-level issue affects all pods | Check node health |
| **Service Latency High** | High CPU causes slow responses | Confirm correlation |
| **HTTP 5xx Errors** | Application errors from CPU throttling | Check error rates |
| **HPA Max Replicas** | Scaling limit reached | Consider limit increase |
| **Pod Pending** | Resource shortage | Check node capacity |

### Alert Correlation Queries | 告警关联查询

```promql
# Check for related alerts in the same namespace
ALERTS{namespace="${NAMESPACE}", alertstate="firing"}

# Check for node-level alerts on the same node
ALERTS{node="${NODE_NAME}", alertstate="firing"}

# Check for service-level alerts
ALERTS{service="${APP_NAME}", alertstate="firing"}
```

### Dependencies and Service Map | 依赖和服务地图

```
${APP_NAME}
    │
    ├── Upstream Dependencies (受影响的上游)
    │   ├── API Gateway / Ingress
    │   └── Load Balancer
    │
    ├── Downstream Dependencies (依赖的下游)
    │   ├── MySQL Database
    │   │   └── Servers: aws-luckyus-salesorder-rw, etc.
    │   ├── Redis Cache
    │   │   └── Clusters: luckyus-isales-order, etc.
    │   └── Other Microservices
    │
    └── Shared Resources (共享资源)
        ├── Node Resources
        └── Network Bandwidth
```

---

## 13. Historical Context | 历史背景

### Common Patterns Observed | 观察到的常见模式

| Pattern | Description | Typical Time | Mitigation |
|---------|-------------|--------------|------------|
| **Morning Peak** | Breakfast rush (7-9 AM ET) | Daily | Pre-scale at 6:30 AM |
| **Lunch Peak** | Lunch orders (11 AM - 1 PM ET) | Daily | HPA handles usually |
| **Marketing Campaign** | Promotion traffic spike | Event-based | Pre-coordinate with marketing |
| **Batch Processing** | Scheduled jobs | Usually 2-4 AM ET | Review job schedules |
| **Deployment** | New code deployment | On-demand | Monitor post-deploy |

### Seasonal Considerations | 季节性考虑

| Season/Event | Expected Impact | Preparation |
|--------------|-----------------|-------------|
| **Chinese New Year** | 150-200% normal traffic | Double capacity |
| **Black Friday** | 180% normal traffic | Pre-scale + monitoring |
| **New Store Launch** | Regional traffic spike | Regional scaling |
| **App Update** | Initial spike then normal | Monitor first 24 hours |
| **Summer Season** | Higher iced drink orders | Baseline increase 20% |

### Known Problematic Services | 已知有问题的服务

| Service | Known Issue | Workaround |
|---------|-------------|------------|
| `isalesorder` | CPU spike during peak | Pre-scale before peaks |
| `ipayment` | Memory leak over time | Scheduled restarts |
| `idelivery` | External API dependency | Circuit breaker enabled |

### Historical Incident Summary | 历史事件摘要

| Date | Service | Root Cause | Resolution Time | Post-Mortem |
|------|---------|------------|-----------------|-------------|
| (To be filled with actual incidents) | | | | |

---

## 14. Prevention Recommendations | 预防建议

### 14.1 Proactive Monitoring Suggestions | 主动监控建议

**Additional Alerts to Consider:**

```yaml
# CPU Warning Alert (before P0 threshold)
- alert: PodCPUWarning
  expr: |
    (sum(rate(container_cpu_usage_seconds_total{container!="POD"}[5m])) by (pod,namespace)
    / sum(container_spec_cpu_quota{container!="POD"} / 100000) by (pod,namespace)) * 100 > 70
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "Pod CPU approaching limit"
    description: "Pod {{ $labels.pod }} CPU at {{ $value }}%"

# CPU Throttling Alert
- alert: PodCPUThrottling
  expr: |
    rate(container_cpu_cfs_throttled_seconds_total[5m]) > 0.1
  for: 5m
  labels:
    severity: warning
  annotations:
    summary: "Pod experiencing CPU throttling"

# Predictive Alert (CPU trending up)
- alert: PodCPUTrending
  expr: |
    predict_linear(
      (sum(rate(container_cpu_usage_seconds_total{container!="POD"}[5m])) by (pod)
      / sum(container_spec_cpu_quota{container!="POD"} / 100000) by (pod)) * 100
    [30m], 3600) > 90
  for: 10m
  labels:
    severity: warning
  annotations:
    summary: "Pod CPU predicted to exceed 90% within 1 hour"
```

### 14.2 Capacity Planning Guidelines | 容量规划指南

**Resource Request/Limit Guidelines:**

| Application Type | CPU Request | CPU Limit | Memory Request | Memory Limit |
|------------------|-------------|-----------|----------------|--------------|
| API Service | 250m-500m | 1000m-2000m | 256Mi-512Mi | 512Mi-1Gi |
| Worker Service | 500m-1000m | 2000m-4000m | 512Mi-1Gi | 1Gi-2Gi |
| Data Processing | 1000m-2000m | 4000m-8000m | 1Gi-2Gi | 2Gi-4Gi |

**HPA Configuration Best Practices:**

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: ${APP_NAME}-hpa
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: ${APP_NAME}
  minReplicas: 3  # Always have redundancy
  maxReplicas: 20  # Set reasonable upper bound
  metrics:
  - type: Resource
    resource:
      name: cpu
      target:
        type: Utilization
        averageUtilization: 70  # Scale before 85% threshold
  behavior:
    scaleUp:
      stabilizationWindowSeconds: 60
      policies:
      - type: Percent
        value: 100
        periodSeconds: 60
    scaleDown:
      stabilizationWindowSeconds: 300  # Prevent thrashing
      policies:
      - type: Percent
        value: 10
        periodSeconds: 60
```

### 14.3 Code Review Checkpoints | 代码审查检查点

**Performance Review Checklist:**

```
□ No unbounded loops without exit conditions
□ Database queries are optimized (indexes, limits)
□ External API calls have timeouts configured
□ Connection pools are properly sized
□ Caching is implemented where appropriate
□ Async operations used for non-blocking tasks
□ No synchronous calls in hot paths
□ Memory allocations are bounded
□ Logging is not excessive in hot paths
□ Metrics collection is efficient
```

### 14.4 Load Testing Requirements | 负载测试要求

**Before Production Deployment:**

| Test Type | Requirement | Tool |
|-----------|-------------|------|
| **Baseline** | Normal load for 1 hour | k6, JMeter |
| **Stress** | 2x normal load for 30 min | k6, Locust |
| **Spike** | Sudden 10x spike | k6 |
| **Soak** | Normal load for 24 hours | k6 |
| **Breakpoint** | Find failure point | k6 |

**Load Test Checklist:**

```
□ Test environment matches production configuration
□ CPU usage stays below 70% at normal load
□ CPU usage stays below 85% at 2x load
□ Response times meet SLA at all load levels
□ No memory leaks during soak test
□ Graceful degradation at breakpoint
□ Auto-scaling behaves as expected
□ Results documented and reviewed
```

### 14.5 Regular Review Tasks | 定期审查任务

| Task | Frequency | Owner |
|------|-----------|-------|
| Review CPU utilization trends | Weekly | DevOps |
| Audit HPA configurations | Monthly | Platform Team |
| Review alert thresholds | Quarterly | SRE Team |
| Capacity planning review | Quarterly | Engineering Managers |
| Load test critical services | Before major releases | QA Team |
| Update runbook | After each incident | On-call + SRE |

---

## Appendix A: Quick Reference Card | 附录A：快速参考卡

### Print This Page for Quick Access | 打印此页以便快速访问

```
╔══════════════════════════════════════════════════════════════╗
║          P0 CPU ALERT QUICK REFERENCE                        ║
║          P0 CPU告警快速参考                                    ║
╠══════════════════════════════════════════════════════════════╣
║ THRESHOLD: > 85% CPU for 3 minutes                           ║
║ SLA: Respond < 5 min | Resolve < 30 min                      ║
╠══════════════════════════════════════════════════════════════╣
║ FIRST 5 MINUTES:                                             ║
║ 1. Acknowledge alert                                         ║
║ 2. kubectl top pod ${POD} -n ${NS}                          ║
║ 3. kubectl describe pod ${POD} -n ${NS}                     ║
║ 4. Open Grafana dashboard                                    ║
║ 5. Post initial status                                       ║
╠══════════════════════════════════════════════════════════════╣
║ QUICK FIXES:                                                 ║
║ Scale:    kubectl scale deploy ${DEPLOY} -n ${NS} --replicas=X ║
║ Restart:  kubectl rollout restart deploy ${DEPLOY} -n ${NS}    ║
║ Kill Pod: kubectl delete pod ${POD} -n ${NS}                   ║
╠══════════════════════════════════════════════════════════════╣
║ ESCALATION:                                                  ║
║ 15 min → Team Lead | 30 min → EM | 60 min → Incident Cmd    ║
╠══════════════════════════════════════════════════════════════╣
║ DASHBOARD: jumbgrafana.luckincoffee.us/grafana/d/mESvEBOnk  ║
╚══════════════════════════════════════════════════════════════╝
```

---

## Appendix B: Environment Variables Template | 附录B：环境变量模板

Copy and fill in when responding to an alert:

```bash
# ============================================
# ALERT RESPONSE ENVIRONMENT SETUP
# Fill in values from alert notification
# ============================================

# From Alert
export POD_NAME=""           # {{.Labels.pod}}
export POD_IP=""             # {{.Labels.pod_ip}}
export APP_NAME=""           # {{.Labels.label_appName}}
export CLUSTER=""            # {{.Labels.cluster}}
export NODE_NAME=""          # {{.Labels.node}}
export CPU_VALUE=""          # {{.Value}}

# Derived (determine from context)
export NAMESPACE=""          # Determine from pod name or service mapping
export DEPLOYMENT_NAME=""    # Usually same as APP_NAME

# AWS
export CLUSTER_NAME="luckyus-prod"
export AWS_REGION="us-east-1"

# Timestamps for documentation
export ALERT_TIME=$(date +"%Y-%m-%d %H:%M:%S %Z")
export INCIDENT_ID="INC-$(date +%Y%m%d%H%M)"
```

---

## Document Control | 文档控制

| Version | Date | Author | Changes |
|---------|------|--------|---------|
| 1.0 | 2026-01-02 | DevOps Team | Initial version |

**Next Review Date:** 2026-04-02

---

*This runbook is a living document. Please update it after each incident with lessons learned.*

*本手册是活文档，请在每次事件后更新经验教训。*
