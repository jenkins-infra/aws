provider "aws" {
  region = var.region
  default_tags {
    tags = local.common_tags
  }
}

provider "local" {
}

provider "random" {
}

provider "kubernetes" {
  alias                  = "eks-public"
  host                   = module.eks-public.cluster_endpoint
  cluster_ca_certificate = base64decode(module.eks-public.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.public-cluster.token
}

provider "kubernetes" {
  alias                  = "cik8s"
  host                   = module.cik8s.cluster_endpoint
  cluster_ca_certificate = base64decode(module.cik8s.cluster_certificate_authority_data)
  token                  = data.aws_eks_cluster_auth.cik8s.token
}
