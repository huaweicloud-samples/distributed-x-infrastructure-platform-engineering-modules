# cce-node-pool-env 模块

CCE 集群 + 节点池（节点形态的容器运行环境）。

## 用途

提供带节点池的 CCE 集群，节点按需弹性；适合需要固定节点规格、复用节点资源的容器工作负载。

## 使用方式

```hcl
module "node_env" {
  source = "../cce-node-pool-env"

  project_name       = "demo"
  vpc_id             = module.vpc.vpc_id
  subnet_id          = module.vpc.private_subnet_one_id
  node_key_pair      = "demo-keypair"
  node_pool_flavor   = "s6.xlarge.2"
  initial_node_count = 1
  max_node_count     = 5
}
```

## 资源构成

| 资源 | 说明 |
|---|---|
| `huaweicloud_cce_cluster.this` | CCE 集群 |
| `huaweicloud_cce_node_pool.this` | CCE 节点池 |
| `huaweicloud_smn_topic.ping` | 消息通知主题 |

## 关键输出

| 输出 | 说明 |
|---|---|
| `cluster_id` | 集群 ID |
| `cluster_name` | 集群名称 |
| `node_pool_id` | 节点池 ID |
| `ping_topic_urn` | 消息通知主题标识 |

> 本模块为独立 Terraform 模块，可独立部署，也可被上层配置直接引用。
