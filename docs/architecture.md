# 架构说明（Architecture）

## 总体定位

`distributed-x-infrastructure-platform-engineering-modules` 是一组面向华为云的 Terraform 模块库，封装平台工程场景下的典型云原生架构模式（VPC 底座、CCE 集群、容器服务、函数计算、负载均衡、对象存储等），可直接组合使用。

## 模块清单（17 个）

| 模块 | 类别 | 用途 |
|---|---|---|
| `vpc-env` | 环境层 | 基础 VPC + 公私网子网 + SMN 主题 |
| `cce-node-pool-env` | 环境层 | CCE 集群 + 节点池（节点形态） |
| `cce-cluster-env` | 环境层 | CCE 集群（无服务器风格） |
| `functiongraph-vpc` | 环境层 | 单 VPC + 单 FunctionGraph 函数（最小示例） |
| `apig-functiongraph-svc` | 服务层 | APIG + FunctionGraph（HTTP API） |
| `cae-webapp-svc` | 服务层 | SWR 镜像仓库 + CCE Namespace（CAE 风格） |
| `backend-node-svc` | 服务层 | CCE Deployment（节点池调度） |
| `backend-serverless-svc` | 服务层 | CCE Deployment（无节点选择） |
| `elb-backend-node-svc` | 服务层 | ELB + CCE Deployment（节点池调度） |
| `elb-backend-serverless-svc` | 服务层 | ELB + CCE Deployment（无服务器） |
| `scheduled-node-svc` | 服务层 | K8s CronJob（节点池调度） |
| `scheduled-serverless-svc` | 服务层 | FunctionGraph 定时触发 |
| `scheduled-function-svc` | 服务层 | FunctionGraph 定时 + VPC 网络 |
| `worker-node-svc` | 服务层 | DMS Kafka + CCE 消费者（节点池调度） |
| `worker-serverless-svc` | 服务层 | DMS Kafka + CCE 消费者（无服务器） |
| `worker-function-svc` | 服务层 | DMS Kafka + FunctionGraph 消费者 |
| `obs-bucket-component` | 组件层 | OBS 桶（最小可复用组件） |

## 典型组合

### 组合 1：对外 HTTP 服务

```
vpc-env
  └── cce-cluster-env (CCE 集群)
        └── elb-backend-serverless-svc (ELB + Deployment)
              └── obs-bucket-component (静态资源)
```

适用：网站 / API 服务 / 前后端分离应用。

### 组合 2：异步任务处理

```
vpc-env
  ├── cce-cluster-env (CCE 集群)
  └── worker-function-svc (DMS Kafka + FunctionGraph)
```

适用：消息驱动的批处理、解耦慢任务、削峰填谷。

### 组合 3：定时任务

```
vpc-env
  ├── cce-cluster-env (CCE 集群)
  └── scheduled-serverless-svc (FunctionGraph 定时) 或 scheduled-node-svc (CronJob)
```

适用：定时清理、定时同步、定时报表。

### 组合 4：内部微服务

```
vpc-env
  ├── cce-cluster-env (CCE 集群)
  ├── backend-serverless-svc (后端 Service)
  └── apig-functiongraph-svc (前端 API 网关)
```

适用：微服务架构。

## 关键设计决策

### 1. 工作负载（Deployment / Service）由 kubectl 部署

每个服务模块的 Terraform 只声明命名空间 + 网络 + IAM 委托 + 镜像仓库等基础设施。**K8s 工作负载（Deployment / Service / HPA / CronJob）由 kubectl 部署**，原因：

- Terraform 与 kubectl 在 K8s 资源上易产生 drift
- K8s 资源更新频率高（Deployment 滚动升级、HPA 自动调整），不适合 Terraform 静态管理
- 模块通过 `deployment_yaml_hint` 输出 K8s YAML 模板，业务方可直接 `kubectl apply -f -`

### 2. 不引入任何外部编排层

本模块库是标准 Terraform 模块集合，所有能力均由 `huaweicloud` Provider 声明。每个模块独立 `terraform apply`，上层配置按需组合引用。

### 3. 容器网络统一走 CNI

CCE 强制使用 CNI 网络插件，因此所有容器工作负载统一按 CNI 模型编排：容器直连 VPC 网段、以 IP 类型后端接入负载均衡。需要「固定节点规格」语义时，通过 CCE 节点池 + `nodeSelector` 实现。

### 4. 消息队列统一使用 DMS Kafka

本模块库的消息队列统一使用 DMS Kafka，并用独立 Topic 承载死信消息。轻量场景可改用 DMS RabbitMQ（本模块未覆盖）。

### 5. CI/CD 由 CodeArts Pipeline 承担

持续集成与部署由 CodeArts Pipeline / CodeArts Build 承担；本模块库只负责基础设施声明，不在 Terraform 中耦合流水线定义。
