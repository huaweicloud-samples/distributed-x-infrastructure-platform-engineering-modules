# cce-cluster-env 模块

CCE 集群（Turbo）+ 消息通知主题。

## 用途

提供 CCE Turbo 集群，容器网络直通 VPC，算力由节点池按需提供并支持无服务器算力形态。

## 使用方式

```hcl
module "cluster_env" {
  source = "../cce-cluster-env"

  project_name = "demo"
  region       = "cn-north-4"
  vpc_id       = module.vpc.vpc_id
  subnet_id    = module.vpc.private_subnet_one_id
}
```

## 资源构成

| 资源 | 说明 |
|---|---|
| `huaweicloud_cce_cluster.this` | CCE 集群（Turbo） |
| `huaweicloud_networking_secgroup.cce_default` | 集群默认安全组 |
| `huaweicloud_smn_topic.ping` | 消息通知主题 |

## 关键输出

| 输出 | 说明 |
|---|---|
| `cluster_id / cluster_name` | 集群 ID / 名称 |
| `cluster_status` | 集群状态 |
| `security_group_id` | 集群默认安全组 ID |
| `ping_topic_urn / ping_topic_name` | 消息通知主题标识 |

> 本模块为独立 Terraform 模块，可独立部署，也可被上层配置直接引用。
