# # https://docs.aws.amazon.com/eks/latest/userguide/managing-kube-proxy.html
# resource "aws_eks_addon" "kube-proxy" {
#   cluster_name = module.eks.cluster_id
#   addon_name   = "kube-proxy"
# }

# # https://docs.aws.amazon.com/eks/latest/userguide/managing-coredns.html
# resource "aws_eks_addon" "coredns" {
#   cluster_name = module.eks.cluster_id
#   addon_name   = "coredns"
# }

# # https://docs.aws.amazon.com/eks/latest/userguide/pod-networking.html
# resource "aws_eks_addon" "vpc-cni" {
#   cluster_name = module.eks.cluster_id
#   addon_name   = "vpc-cni"
# }
