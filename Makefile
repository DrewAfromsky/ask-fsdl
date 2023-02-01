ifneq (,$(wildcard ./.env))
    include .env
	# assume includes MODAL_TOKEN_ID and MODAL_TOKEN_SECRET for modal auth,
	# assume includes MODAL_USER_NAME and DISCORD_AUTH for running discord bot
	# assume includes MONGODB_URI and MONGODB_PASSWORD for document store setup
    export
endif

.PHONY: help
.DEFAULT_GOAL := help

help: ## get a list of all the targets, and their short descriptions
	@# source for the incantation: https://marmelab.com/blog/2016/02/29/auto-documented-makefile.html
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' Makefile | awk 'BEGIN {FS = ":.*?##"}; {printf "\033[36m%-12s\033[0m %s\n", $$1, $$2}'

discord_bot: environment ## run the Discord bot frontend locally
	@echo "###"
	@echo "# 🥞: Assumes you've set up your bot and deployed the backend on Modal"
	@echo "###"
	python run_bot.py

deploy_backend: modal_auth ## deploy the Q&A backend on Modal
	@echo "###"
	@echo "# 🥞: Assumes you've set up the vector storage"
	@echo "###"
	modal deploy app.py

local_query: modal_auth ## run a test query locally
	@echo "###"
	@echo "# 🥞: Assumes you've set up the vector storage"
	@echo "###"
	modal run app.py::stub.cli --query "What is PyTorch?"

document_storage: dev_environment ## runs the corpus generation notebook locally, stor
	@echo "###"
	@echo "# 🥞: Assumes you've created a Mongo database with name fsdl and collection ask-fsdl first"
	@echo "###"
	nbconvert jupyter nbconvert --ExecutePreprocessor.timeout=600 --to notebook --execute "Building the FSDL Corpus.ipynb"

vector_storage: modal_auth ## updates a Pinecone vector store to contain embeddings of the document corpus
	@echo "###"
	@echo "# 🥞: Assumes you've set up the document storage
	@echo "###"
	modal run app.py::stub.sync_vector_db_to_doc_db

debugger: modal_auth ## starts a debugger in the terminal running on Modal's infra
	modal run app::stub.debug

modal_auth: environment ## confirms authentication with Modal, using secrets from `.env` file
	@echo "###"
	@echo "# 🥞: If you haven't gotten a Modal token yet, run make modal_token
	@echo "###"
	@modal token set --token-id $(MODAL_TOKEN_ID) --token-secret $(MODAL_TOKEN_SECRET)

modal_token: environment ## creates token ID and secret for authentication with modal
	modal token new
	@echo "###"
	@echo "# 🥞: Copy the token info from the file mentioned above into .env"
	@echo "###"

environment: ## installs required environment for deployment
	pip install -qqq -r requirements.txt

dev_environment:  ## installs required environment for document corpus generation
	pip install -qqq -r requirements-dev.txt
