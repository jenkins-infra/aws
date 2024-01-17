provider "aws" {
  region = var.region
  default_tags {
    tags = {
      scope           = "terraform-managed"
      repository      = "jenkins-infra/aws"
      "cb:user"       = "dduportal"
      "cb:production" = "production"
      "cb:owner"      = "Community-Team"
      "cb-env-type"   = "external"
    }
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
  host                   = data.aws_eks_cluster.cik8s.endpoint
  cluster_ca_certificate = base64decode(data.aws_eks_cluster.cik8s.certificate_authority[0].data)
  token                  = data.aws_eks_cluster_auth.cik8s.token
}
