RPC_URL ?= http://localhost:8545

.PHONY: all
all: test

.PHONY: test
test:
	forge test -vvv

.PHONY: deploy
deploy:
	forge script script/Deploy.s.sol:Deploy \
		--rpc-url $(RPC_URL) --private-key $(PK) --broadcast -vvv

.PHONY: fmt
fmt:
	forge fmt script/ src/*.sol test/

.PHONY: install
install:
	git submodule update --init --recursive
