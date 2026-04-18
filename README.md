# devops-scripts

A collection of production-grade shell scripts for AWS, Kubernetes, monitoring, CI/CD, and security operations. Each script is self-contained with clear usage instructions and no hidden dependencies.

## Structure

```
devops-scripts/
├── aws/
│   ├── rotate-iam-keys.sh       # Rotate IAM access keys safely with deactivation before deletion
│   ├── assume-role.sh           # Assume an IAM role and export credentials to the shell
│   └── ec2-cost-report.sh       # On-demand cost estimate table grouped by environment tag
│
├── kubernetes/
│   ├── pod-restarts-report.sh   # Report pods exceeding a restart threshold across namespaces
│   ├── drain-node-safe.sh       # Cordon + drain a node with confirmation prompt
│   └── rollback-deployment.sh   # Roll back a deployment with before/after image audit
│
├── monitoring/
│   ├── alert-silence.sh         # Create an Alertmanager silence via API
│   └── slo-burn-check.sh        # Query Prometheus and compute error budget burn rate
│
├── ci-cd/
│   ├── tag-and-release.sh       # Git tag + GitHub release with auto-generated changelog
│   └── argocd-sync-wait.sh      # Trigger ArgoCD sync and wait for Healthy/Synced
│
├── security/
│   ├── scan-exposed-ports.sh    # nmap scan for open ports in a CIDR (authorized use only)
│   └── audit-sg-rules.sh        # Flag AWS Security Groups with 0.0.0.0/0 inbound rules
│
└── utils/
    ├── health-check.sh          # HTTP endpoint poller with Slack alerting on failure
    └── log-tail-filter.sh       # Tail logs across multiple pod replicas with regex filter
```

## Prerequisites

| Category   | Tools needed                     |
|------------|----------------------------------|
| AWS        | `aws-cli v2`, `jq`               |
| Kubernetes | `kubectl`                        |
| Monitoring | `curl`, `jq`, `bc`               |
| CI/CD      | `git`, `gh` (GitHub CLI), `argocd` CLI |
| Security   | `nmap`, `aws-cli v2`, `jq`       |
| Utils      | `curl`, `kubectl`                |

## Usage Examples

### AWS

```bash
# Rotate IAM keys for a user
./aws/rotate-iam-keys.sh alice --profile prod

# Assume a cross-account role (source the script to export creds)
source ./aws/assume-role.sh arn:aws:iam::123456789012:role/DeployRole fintech-deploy

# Cost report for all EC2 instances
./aws/ec2-cost-report.sh --region us-east-1 --profile prod
```

### Kubernetes

```bash
# Show pods with 10+ restarts in the payments namespace
./kubernetes/pod-restarts-report.sh --namespace payments --threshold 10

# Safely drain a node before maintenance
./kubernetes/drain-node-safe.sh ip-10-0-1-25.ec2.internal --context prod-eks

# Roll back the payments deployment
./kubernetes/rollback-deployment.sh payments -n prod --to-revision 3
```

### Monitoring

```bash
# Silence all payments alerts for 2 hours during a deploy
./monitoring/alert-silence.sh \
  --alertmanager http://alertmanager:9093 \
  --matcher "service=payments" \
  --duration 2h \
  --comment "Planned deploy v2.4.1"

# Check SLO burn rate against Prometheus
./monitoring/slo-burn-check.sh \
  --prometheus http://prometheus:9090 \
  --service payments \
  --slo 0.999
```

### CI/CD

```bash
# Tag and release v1.4.2
./ci-cd/tag-and-release.sh v1.4.2 --repo myorg/payments-service

# Sync an ArgoCD app and wait for healthy
./ci-cd/argocd-sync-wait.sh payments-prod --server https://argocd.internal --timeout 300
```

### Security

```bash
# Audit Security Groups for open-to-world rules
./security/audit-sg-rules.sh --region us-east-1 --profile prod

# Scan a subnet for exposed sensitive ports (authorized use only)
./security/scan-exposed-ports.sh 10.0.1.0/24 --ports 22,3306,5432,6379
```

### Utils

```bash
# Monitor an endpoint with Slack alerting after 3 failures
export SLACK_WEBHOOK_URL=https://hooks.slack.com/...
./utils/health-check.sh https://api.payments.internal/health --interval 30 --threshold 3

# Tail logs from all payments pods, filter for errors
./utils/log-tail-filter.sh -l app=payments -n prod --filter "ERROR|WARN" --since 10m
```

## Customization

Every script accepts `--help`-style flags. Key tunables are documented in the header comment of each file. No script hardcodes account IDs, cluster names, or service names — all inputs come from CLI flags or environment variables.

## Security Notes

- `scan-exposed-ports.sh` uses nmap — only run against infrastructure you own or have explicit written authorization to scan.
- `rotate-iam-keys.sh` deactivates the old key but does **not** delete it. Validate the new key first, then delete manually.
- Scripts that interact with production systems (drain, rollback) include a confirmation prompt before taking action.
