REPO ?= github.com/osbkit/minibroker
BINARY ?= minibroker
PKG ?= $(REPO)/cmd/$(BINARY)
REGISTRY ?= carolynvs/
IMAGE ?= $(REGISTRY)minibroker
TAG ?= canary

build:
	go build $(PKG)

test-unit:
	go test -v ./...

test: test-unit test-mariadb test-mysqldb test-postgresql test-mongodb test-wordpress

test-wordpress: setup-wordpress teardown-wordpress

setup-wordpress:
	helm install --name minipress charts/wordpress --wait

teardown-wordpress:
	helm delete --purge minipress

test-mysqldb: setup-mysqldb teardown-mysqldb

setup-mysqldb:
	until svcat get broker minibroker | grep -m 1 Ready; do : ; done

	svcat provision mysqldb --class mysql --plan 5-7-14 --namespace minibroker \
		-p mysqlDatabase=mydb -p mysqlUser=admin
	until svcat get instance mysqldb -n minibroker | grep -m 1 Ready; do : ; done
	svcat get instance mysqldb -n minibroker

	svcat bind mysqldb -n minibroker
	until svcat get binding mysqldb -n minibroker | grep -m 1 Ready; do : ; done
	svcat describe binding mysqldb -n minibroker

teardown-mysqldb:
	svcat unbind mysqldb
	svcat deprovision mysqldb

test-mariadb: setup-mariadb teardown-mariadb

setup-mariadb:
	until svcat get broker minibroker | grep -m 1 Ready; do : ; done

	svcat provision mariadb --class mariadb --plan 10-1-32 --namespace minibroker \
		-p mariadbDatabase=mydb -p mariadbUser=admin
	until svcat get instance mariadb -n minibroker | grep -m 1 Ready; do : ; done
	svcat get instance mariadb -n minibroker

	svcat bind mariadb -n minibroker
	until svcat get binding mariadb -n minibroker | grep -m 1 Ready; do : ; done
	svcat describe binding mariadb -n minibroker

teardown-mariadb:
	svcat unbind mariadb
	svcat deprovision mariadb

test-postgresql: setup-postgresql teardown-postgresql

setup-postgresql:
	until svcat get broker minibroker | grep -m 1 Ready; do : ; done

	svcat provision postgresql --class postgresql --plan 9-6-2 --namespace minibroker \
		-p postgresDatabase=mydb -p postgresUser=admin
	until svcat get instance postgresql -n minibroker | grep -m 1 Ready; do : ; done
	svcat get instance postgresql -n minibroker

	svcat bind postgresql -n minibroker
	until svcat get binding postgresql -n minibroker | grep -m 1 Ready; do : ; done
	svcat describe binding postgresql -n minibroker

teardown-postgresql:
	svcat unbind postgresql
	svcat deprovision postgresql

test-mongodb: setup-mongodb teardown-mongodb

setup-mongodb:
	until svcat get broker minibroker | grep -m 1 Ready; do : ; done

	svcat provision mongodb --class mongodb --plan 3-7-1 --namespace minibroker \
		-p mongodbDatabase=mydb -p postgresUsername=admin
	until svcat get instance mongodb -n minibroker | grep -m 1 Ready; do : ; done
	svcat get instance mongodb -n minibroker

	svcat bind mongodb -n minibroker
	until svcat get binding mongodb -n minibroker | grep -m 1 Ready; do : ; done
	svcat describe binding mongodb -n minibroker

teardown-mongodb:
	svcat unbind mongodb
	svcat deprovision mongodb

build-linux:
	GOOS=linux GOARCH=amd64 CGO_ENABLED=0 \
	go build -o $(BINARY)-linux -tags netgo --ldflags="-s" $(PKG)

image: build-linux
	cp $(BINARY)-linux image/$(BINARY)
	docker build image/ -t "$(IMAGE):$(TAG)"

clean:
	-rm -f $(BINARY)

push: image
	docker push "$(IMAGE):$(TAG)"

log:
	kubectl log -n minibroker deploy/minibroker-minibroker -c minibroker

create-cluster:
	./hack/create-cluster.sh

deploy:
	helm upgrade --install minibroker --namespace minibroker \
	--recreate-pods --force charts/minibroker \
	--set image="$(IMAGE):$(TAG)",imagePullPolicy="Always",deploymentStrategy="Recreate"

.PHONY: build log build-linux test image clean push create-cluster deploy
