include .env



TAG_VERSION     ?= $(GORELEASER_VERSION)-$(GO_VERSION)
IMAGE_BASE_NAME := line/goreleaser-cross-base:$(TAG_VERSION)
IMAGE_NAME      := line/goreleaser-cross:$(TAG_VERSION)
SUBIMAGES = amd64

DOCKER_BUILD=docker build

.PHONY: check
check:
	@echo $(patsubst %, goreleaser-cross-%,$(SUBIMAGES))

#################################### Build ###################################

.PHONY: goreleaser-cross goreleaser-final-% goreleaser-final


goreleaser-cross: $(patsubst %, goreleaser-cross-%,$(SUBIMAGES))

goreleaser-cross-%:
	@echo "building $(IMAGE_NAME)-$(@:goreleaser-cross-%=%)"
	$(DOCKER_BUILD) --platform=linux/$(@:goreleaser-cross-%=%) -t $(IMAGE_NAME)-$(@:goreleaser-cross-%=%) \
		--build-arg GO_VERSION=$(GO_VERSION) \
		--build-arg GORELEASER_VERSION=$(GORELEASER_VERSION) \
		--build-arg OSX_SDK=$(OSX_SDK) \
		--build-arg OSX_SDK_SUM=$(OSX_SDK_SUM) \
		--build-arg OSX_VERSION_MIN=$(OSX_VERSION_MIN) \
		--build-arg OSX_CROSS_COMMIT=$(OSX_CROSS_COMMIT) \
		--build-arg DEBIAN_FRONTEND=$(DEBIAN_FRONTEND) \
		-f Dockerfile.final .


#################################### Push ###################################

.PHONY: docker-push-base-% docker-push-% docker-push-base docker-push

docker-push-base: $(patsubst %, docker-push-base-%,$(SUBIMAGES))
docker-push: $(patsubst %, docker-push-%,$(SUBIMAGES))

docker-push-base-%:
	docker push $(IMAGE_BASE_NAME)-$(@:docker-push-base-%=%)

docker-push-%:
	docker push $(IMAGE_NAME)-$(@:docker-push-%=%)




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

