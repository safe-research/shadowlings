RPC ?= http://localhost:8545
PK ?= 0xac0974bec39a17e36ba4a6b4d238ff944bacb478cbed5efcae784d7bf4f2ff80

.PHONY: all
all: test

.PHONY: test
test:
	forge test -vvv

.PHONY: deploy
deploy:
	forge script script/Deploy.s.sol:Deploy \
		--rpc-url $(RPC) --private-key $(PK) --broadcast -vvv

.PHONY: fmt
fmt:
	forge fmt script/ src/*.sol test/

.PHONY: install
install:
	git submodule update --init --recursive
