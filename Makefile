include .env

TAG_VERSION     ?= $(GORELEASER_VERSION)-$(GO_VERSION)
WASMVM_VERSION  ?= 1.0.0
IMAGE_BASE_NAME := tkxkd0159/goreleaserx:$(TAG_VERSION)
IMAGE_NAME      := tkxkd0159/goreleaserx-wasm:$(WASMVM_VERSION)
SUBIMAGES = amd64

DOCKER_BUILD=docker build

#################################### Build ###################################

.PHONY: docker-build-% docker-build docker-build-base-% docker-build-base


docker-build-base: $(patsubst %, docker-build-base-%,$(SUBIMAGES))
docker-build: $(patsubst %, docker-build-%,$(SUBIMAGES))

docker-build-base-%:
	@echo "building $(IMAGE_BASE_NAME)-$(@:docker-build-base-%=%)"
	$(DOCKER_BUILD) --platform=linux/$(@:docker-build-base-%=%) -t $(IMAGE_BASE_NAME) \
		--build-arg GO_VERSION=$(GO_VERSION) \
		--build-arg GORELEASER_VERSION=$(GORELEASER_VERSION) \
		--build-arg OSX_SDK=$(OSX_SDK) \
		--build-arg OSX_SDK_SUM=$(OSX_SDK_SUM) \
		--build-arg OSX_VERSION_MIN=$(OSX_VERSION_MIN) \
		--build-arg OSX_CROSS_COMMIT=$(OSX_CROSS_COMMIT) \
		--build-arg DEBIAN_FRONTEND=$(DEBIAN_FRONTEND) \
		-f ./docker/final.Dockerfile .

docker-build-%:
	@echo "building $(IMAGE_NAME)-$(@:docker-build-%=%)"
	$(DOCKER_BUILD) --platform=linux/$(@:docker-build-%=%) -t $(IMAGE_NAME) \
	-f ./docker/wasm.Dockerfile .

#################################### Push ###################################

.PHONY: docker-push-base-% docker-push-% docker-push-base docker-push

docker-push-base: $(patsubst %, docker-push-base-%,$(SUBIMAGES))
docker-push: $(patsubst %, docker-push-%,$(SUBIMAGES))

docker-push-base-%:
	docker push $(IMAGE_BASE_NAME)

docker-push-%:
	docker push $(IMAGE_NAME)



#################################### Manifest ###################################

.PHONY: manifest-create-base manifest-create manifest-push-base manifest-push

manifest-create-base:
	@echo "creating base manifest $(IMAGE_BASE_NAME)"
	docker manifest create $(IMAGE_BASE_NAME) $(foreach arch,$(SUBIMAGES), --amend $(IMAGE_BASE_NAME)-$(arch))

manifest-create:
	@echo "creating manifest $(IMAGE_NAME)"
	docker manifest create $(IMAGE_NAME) $(foreach arch,$(SUBIMAGES), --amend $(IMAGE_NAME)-$(arch))

manifest-push-base:
	@echo "pushing base manifest $(IMAGE_BASE_NAME)"
	docker manifest push $(IMAGE_BASE_NAME)

manifest-push:
	@echo "pushing manifest $(IMAGE_NAME)"
	docker manifest push $(IMAGE_NAME)



.PHONY: tags
tags:
	@echo $(IMAGE_NAME) $(foreach arch,$(SUBIMAGES), $(IMAGE_NAME)-$(arch))

