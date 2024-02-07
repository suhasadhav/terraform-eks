module "lb-controller" {
  source                  = "basisai/lb-controller/aws"
  cluster_name            = module.eks.cluster_name
  cluster_oidc_issuer_url = module.eks.cluster_oidc_issuer_url
  iam_role_path           = null
  depends_on              = [module.eks]
}


resource "helm_release" "nginx" {
  count            = 2
  name             = "nginx${count.index}"
  repository       = "https://charts.bitnami.com/bitnami"
  chart            = "nginx"
  namespace        = "nginx"
  create_namespace = true
  values = [
    file("${path.module}/files/nginx-values.yaml")
  ]
  depends_on = [module.lb-controller]
}


resource "kubernetes_manifest" "networkpolicy" {
  manifest = yamldecode(<<-EOF
    kind: NetworkPolicy
    apiVersion: networking.k8s.io/v1
    metadata:
      namespace: nginx
      name: deny-from-other-namespaces
    spec:
      podSelector:
        matchLabels: {}
      ingress:
      - from:
        - podSelector: {}
    EOF
  )
  depends_on = [helm_release.nginx]
}

resource "kubernetes_manifest" "ingress" {
  manifest = yamldecode(<<-EOF
    apiVersion: networking.k8s.io/v1
    kind: Ingress
    metadata:
      name: my-alb-ingress
      namespace: nginx
      annotations:
        kubernetes.io/ingress.class: alb
        alb.ingress.kubernetes.io/target-type: ip
        alb.ingress.kubernetes.io/scheme: internet-facing
        alb.ingress.kubernetes.io/listen-ports: '[{"HTTP": 80}]'
        alb.ingress.kubernetes.io/actions.order: '{"Name": "default", "Type": "forward", "ForwardConfig": {"TargetGroups": {"tg-0": {"Weight": 1}, "tg-1": {"Weight": 1}}}}'
        alb.ingress.kubernetes.io/actions.default.weight: "1"
    spec:
      rules:
        - host: suhas.com
          http:
            paths:
              - path: /service1
                pathType: Prefix
                backend:
                  service:
                    name: nginx1
                    port:
                      number: 80
              - path: /service2
                pathType: Prefix
                backend:
                  service:
                    name: nginx2
                    port:
                      number: 80
    EOF
  )
  depends_on = [helm_release.nginx]
}

resource "kubernetes_manifest" "tgb" {
  count = 2
  manifest = yamldecode(<<-EOF
    apiVersion: elbv2.k8s.aws/v1beta1
    kind: TargetGroupBinding
    metadata:
      name: nginx1
      namespace: nginx${count.index}
    spec:
      ipAddressType: ipv4
      networking:
        ingress:
        - from:
          ports:
          - port: 80
            protocol: TCP
      serviceRef:
        name: nginx
        port: 80
      targetGroupARN: "${aws_lb_target_group.tg[count.index].arn}"
      targetType: ip
    EOF
  )
  depends_on = [helm_release.nginx]
}
