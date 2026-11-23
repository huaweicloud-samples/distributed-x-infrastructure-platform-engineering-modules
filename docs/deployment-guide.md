# 部署指导书（Deployment Guide）

## 1. 前置条件

| 项 | 要求 |
|---|---|
| 华为云账号 | 已开通 cn-north-4 区域 |
| Terraform | >= 1.5 |
| huaweicloud Provider | ~> 1.70 |
| kubectl | >= 1.27（用于部署 CCE 工作负载） |
| 华为云 Access Key | 在华为云「我的凭证」页面获取 Access Key，并填入部署脚本（`HW_ACCESS_KEY` / `HW_SECRET_KEY`） |
| OBS 桶（用于 FunctionGraph 代码包） | 自建桶 + 上传 zip 代码 |

## 2. 准备代码包

每个 FunctionGraph 模块（`apig-functiongraph-svc` / `scheduled-*` / `worker-function-svc` / `functiongraph-vpc`）需要 zip 代码包。约定：

- 代码包路径：`obs://<your-bucket>/function-code/<function-name>.zip`
- 函数入口：`index.handler`
- 运行时：`Python3.10`（可在模块 variables 中调整）

### 示例：打包 FunctionGraph 函数

```python
# src/handler.py
import json

def handler(event, context):
    return {
        "statusCode": 200,
        "body": json.dumps({"message": "hello from FunctionGraph"})
    }
```

打包：

```bash
zip function.zip handler.py
# 上传到 OBS
```

## 3. 部署 vpc-env（基础设施）

```hcl
module "vpc" {
  source = "../infra/modules/vpc-env"

  project_name = "demo"
  region       = "cn-north-4"
  vpc_cidr     = "10.0.0.0/16"
}

output "vpc_id"             { value = module.vpc.vpc_id }
output "public_subnet_one"  { value = module.vpc.public_subnet_one_id }
output "private_subnet_one" { value = module.vpc.private_subnet_one_id }
output "ping_topic_urn"     { value = module.vpc.ping_topic_urn }
```

```bash
terraform init
terraform apply -auto-approve
```

## 4. 部署 cce-cluster-env（CCE 集群）

```hcl
module "cce" {
  source = "../infra/modules/cce-cluster-env"

  project_name = "demo"
  region       = "cn-north-4"
  vpc_id       = module.vpc.vpc_id
  subnet_id    = module.vpc.private_subnet_one_id
}

output "cluster_id" { value = module.cce.cluster_id }
```

## 5. 部署 elb-backend-serverless-svc（ELB + K8s 工作负载）

### 5.1 Terraform 部署基础设施

```hcl
module "lb_svc" {
  source = "../infra/modules/elb-backend-serverless-svc"

  project_name        = "demo-app"
  vpc_id              = module.vpc.vpc_id
  cluster_id          = module.cce.cluster_id
  public_subnet_ids   = [module.vpc.public_subnet_one_id, module.vpc.public_subnet_two_id]
  service_subnet_ids  = [module.vpc.private_subnet_one_id, module.vpc.private_subnet_two_id]
  image_url           = "swr.cn-north-4.myhuaweicloud.com/demo/app:latest"
  container_port      = 8080
  replicas            = 2
  ping_topic_urn      = module.vpc.ping_topic_urn
}

output "elb_ip" { value = module.lb_svc.elb_ip }
```

### 5.2 kubectl 部署 K8s 工作负载

```bash
# 配置 kubectl
# 用 CCE 控制台获取 KubeConfig：
# 1. 登录华为云控制台 → CCE → 集群 → demo-cce
# 2. 集群信息 → 连接信息 → 复制 KubeConfig 到 ~/.kube/config

# 部署
terraform output -raw lb_svc_deployment_yaml > /tmp/app.yaml
kubectl apply -f /tmp/app.yaml
```

## 6. 部署 apig-functiongraph-svc（APIG + FunctionGraph）

```hcl
module "api" {
  source = "../infra/modules/apig-functiongraph-svc"

  project_name      = "demo-api"
  vpc_id            = module.vpc.vpc_id
  subnet_id         = module.vpc.private_subnet_one_id
  security_group_id = module.vpc.vpc_default_security_group_id
  function_code_url = "https://demo-bucket.obs.cn-north-4.myhuaweicloud.com/function-code/api.zip"
  ping_topic_urn    = module.vpc.ping_topic_urn
}

output "api_url" { value = module.api.apig_api_url }
output "api_invoke_url" { value = module.api.apig_invoke_url }
```

## 7. 部署 worker-function-svc（DMS Kafka + FunctionGraph 消费者）

```hcl
module "worker" {
  source = "../infra/modules/worker-function-svc"

  project_name      = "demo-worker"
  vpc_id            = module.vpc.vpc_id
  subnet_id         = module.vpc.private_subnet_one_id
  security_group_id = module.vpc.vpc_default_security_group_id
  function_code_url = "https://demo-bucket.obs.cn-north-4.myhuaweicloud.com/function-code/worker.zip"
}
```

DMS Kafka 触发器由 `huaweicloud_fgs_function_trigger` 资源在 `apply` 时自动创建（topic = `${project_name}-processing`、消费组 = `${project_name}-consumer`、Kafka 端口 9092）。**无需在控制台手工配置**；前提是函数已开启 VPC 访问且安全组放行 9092 入站（本模块已在函数上配置 `vpc_id`/`network_id`/`security_group_id`）。

## 8. 验证

### 8.1 验证 VPC

```bash
terraform output vpc_id
# 用华为云控制台 → VPC → 查看 demo-vpc 是否存在
```

### 8.2 验证 CCE 集群

```bash
terraform output cluster_id
# 控制台 → CCE → 集群 → demo-cce 应为「运行中」
```

### 8.3 验证 ELB

```bash
terraform output elb_ip
# 访问 http://<elb_ip> 应返回 200（前提是 K8s 工作负载已部署）
```

### 8.4 验证 APIG

```bash
terraform output api_invoke_url
# curl https://<api_invoke_url> 应返回 200
# （完整调用地址由模块拼装；确切路径段以华为云控制台 APIG → API 详情「调用地址」为准）
```

## 9. 清理

```bash
# 按依赖顺序反向销毁
terraform destroy
```

确认所有资源已被删除（控制台核查）。

## 10. 常见问题

| 问题 | 解决 |
|---|---|
| `Error: VPC quota exceeded` | 提交工单提升 VPC 配额 |
| `Error: ELB flavor not available in zone` | 调整 availability_zone 列表或更换 flavor |
| CCE 集群创建超时 | 检查安全组规则；CCE 默认需要 22 / 5443 端口放行 |
| FunctionGraph 上传代码失败 | 检查 OBS 桶权限 + 桶策略 |
| DMS Kafka 触发器不触发 | 检查 FunctionGraph 委托是否含 DMS 权限 |
