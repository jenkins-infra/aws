provider "aws" {
  region = var.region
  default_tags {
    tags = {
      scope      = "terraform-managed"
      repository = "jenkins-infra/aws"
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
