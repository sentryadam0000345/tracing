SENTRY_ORG=testorg-az
SENTRY_PROJECT=will-frontend-react
VERSION=`sentry-cli releases propose-version`
PREFIX=static/js

REPOSITORY=us.gcr.io/sales-engineering-sf
COMMIT_SHA=$(shell git rev-parse HEAD)
GCP_DEPLOY=gcloud run deploy $(shell whoami)

all: build_react setup_release build deploy-flask deploy-react
docker_compose:
	cd react && npm run buildlocal
	docker-compose build
	docker-compose run -d -e VERSION=$(VERSION) -e FLASK_ENV=test -p 3003:3003 flask
	docker-compose run -p 3002:3002 react

build_react:
	cd react && source $(HOME)/.nvm/nvm.sh && nvm use && npm install && npm run build

setup_release: create_release associate_commits upload_sourcemaps

create_release:
	sentry-cli releases -o $(SENTRY_ORG) new -p $(SENTRY_PROJECT) $(VERSION)
associate_commits:
	sentry-cli releases -o $(SENTRY_ORG) -p $(SENTRY_PROJECT) set-commits --auto $(VERSION)
upload_sourcemaps:
	sentry-cli releases -o $(SENTRY_ORG) -p $(SENTRY_PROJECT) files $(VERSION) \
		upload-sourcemaps --url-prefix "~/$(PREFIX)" --validate react/build/$(PREFIX)

build:
	gcloud builds submit --substitutions=COMMIT_SHA=$(COMMIT_SHA) --config=cloudbuild.yaml
deploy-flask:
	$(GCP_DEPLOY)-flask --image $(REPOSITORY)/workspace_flask:$(COMMIT_SHA) --platform managed --add-cloudsql-instances sales-engineering-sf:us-central1:tracing-db-pg --update-env-vars INSTANCE_CONNECTION_NAME="sales-engineering-sf:us-central1:tracing-db-pg",VERSION=$(VERSION)
deploy-react:
	$(GCP_DEPLOY)-react --image $(REPOSITORY)/workspace_react:$(COMMIT_SHA) --platform managed

.PHONY: all build_react setup_release create_release associate_commits upload_sourcemaps build deploy-flask deploy-react docker_compose
