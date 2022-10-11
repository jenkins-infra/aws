provider "aws" {
  region = var.region
}

provider "local" {
}

provider "random" {
}

provider "kubernetes" {
  alias                  = "eks-public"
  host                   = data.aws_eks_cluster.public-cluster.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.public-cluster.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.public-cluster.token
}
