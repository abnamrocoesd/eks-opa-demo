package kubernetes.admission

import data.kubernetes.namespaces

import input.request.object.metadata.annotations as annotations

deny[msg] {
    input.request.kind.kind = "Ingress"
    input.request.operation = "CREATE"
    missing_required_annotations[msg]
}

missing_required_annotations[msg] {
    not annotations["alb.ingress.kubernetes.io/scheme"] == "internal"
    msg = "Compliance check failed: CISO-01: Application Load Balancers must use 'internal' scheme"
}

missing_required_annotations[msg] {
    not annotations["alb.ingress.kubernetes.io/inbound-cidrs"] == "10.0.0.0/8"
    msg = "Compliance check failed: CISO-02: Application Load Balancers restrict access to trusted IP ranges"
}
