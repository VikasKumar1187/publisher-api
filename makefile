run:
	go run main.go

build:
	go build -ldflags "-X main.build=local"

test:
	go test ./... -count=1
	staticcheck ./...

tidy:
	go mod tidy
	go mod vendor

VERSION:= 1.0

all: publisher-api-image

# ===================================================================================================================================
publisher-api-image:
	docker build --progress=plain -t publisher-api-amd64:$(VERSION) --build-arg BUILD_REF="$(VERSION)" -f zarf/docker/dockerfile .

# ====================================================================================================================================
# Running from within k8s/
KIND_CLUSTER:= publisher-cluster
API_SERVICE_NAMESPACE:= publisher-api-service-system
API_SERVICE_PODNAME:= publisher-api-service-pod

kind-up:
	kind create cluster --image kindest/node:v1.28.0 --name $(KIND_CLUSTER) --config zarf/k8s/kind/kind-config.yaml

kind-down:
	kind delete cluster --name $(KIND_CLUSTER)

kind-load:
	kind load docker-image publisher-api-amd64:$(VERSION) --name $(KIND_CLUSTER)

kind-apply:
	kustomize build zarf/k8s/kind/api-service-pod | kubectl apply -f -
#kubectl apply -f zarf/k8s/base/api-service-pod/base-service.yaml

kind-status:
	kubectl get nodes -o wide
	kubectl get svc -o wide
	kubectl get pods -o wide --watch --all-namespaces

kind-status-publisher:
	kubectl get pods -o wide --watch --namespace=$(API_SERVICE_NAMESPACE)

kind-status-full:
	kubectl describe pod -lapp=api

kind-logs:
	kubectl logs -lapp=api --all-containers=true -f --tail=100 --namespace=$(API_SERVICE_NAMESPACE)

kind-update: all kind-load kind-restart

kind-update-apply: all kind-load kind-apply

kind-restart:
	kubectl rollout restart deployment $(API_SERVICE_PODNAME) --namespace=$(API_SERVICE_NAMESPACE)

kind-describe:
	kubectl describe pod -l app=api --namespace=$(API_SERVICE_NAMESPACE)

kind-delete:
#kubectl delete -f zarf/k8s/base/api-service-pod/base-service.yaml
	kustomize build zarf/k8s/kind/api-service-pod | kubectl delete -f -

