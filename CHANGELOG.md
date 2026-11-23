# Changelog

## [0.3.0](https://github.com/lucawalz/.github/compare/v0.2.0...v0.3.0) (2026-11-23)


### Features

* **tofu:** add an onboard recipe that prepares repository adoption ([390b4fd](https://github.com/lucawalz/.github/commit/390b4fdafb9dd947424e58e47808c0f5121474ac))
* **tofu:** adopt strata into the released tier ([586dd4b](https://github.com/lucawalz/.github/commit/586dd4bf8cf3bc39fb08551a108d91695378060c))
* **tofu:** load r2 credentials per session and check inputs before planning ([8d38cc5](https://github.com/lucawalz/.github/commit/8d38cc546f627ec543aee68a0c640b5397089675))
* **tofu:** plan and apply one repository with an optional key override ([3366878](https://github.com/lucawalz/.github/commit/3366878fe92fdfb02ea8c7917683c863f6761622))


### Bug Fixes

* **onboard:** import only declared rulesets and comment open labels ([3ec2fb0](https://github.com/lucawalz/.github/commit/3ec2fb0f71e9b18ea109035e399b3c5a2e209112))
* **onboard:** install the release app before the apply ([7dbe2f4](https://github.com/lucawalz/.github/commit/7dbe2f47a656d8199537cdd1cf1baf45be354732))
* **onboard:** note release pin timing and move codeql step before callers ([c27e354](https://github.com/lucawalz/.github/commit/c27e35465b1f2cf79dc78c66da837bf4d25980c8))
* **onboard:** validate the repository argument against a strict pattern ([c530757](https://github.com/lucawalz/.github/commit/c53075727cffe6e488b6c01a3e7f3f9d4221a339))
* **tofu:** harden recipe target checks and announce key override ([ddbaad8](https://github.com/lucawalz/.github/commit/ddbaad86e7a0e7f97385b79dce8f915a0d3f1964))
* **tofu:** pass recipe arguments through the environment instead of text ([301da3c](https://github.com/lucawalz/.github/commit/301da3c4088525035d376a5c6927231c3b0320b0))
* **tofu:** treat only a missing branch protection as unprotected when onboarding ([caa7e96](https://github.com/lucawalz/.github/commit/caa7e96bf5e2380e42229392e70822bad7086a0b))

## [0.2.0](https://github.com/lucawalz/.github/compare/v0.1.0...v0.2.0) (2026-11-19)


### Features

* **tofu:** adopt bedrock as deployed tier with path labels ([3e40eb2](https://github.com/lucawalz/.github/commit/3e40eb2c963d57a0e7c85a46afa22acd8afdd162))
* **tofu:** adopt dotfiles and the profile repository as config tier ([1b0ba4f](https://github.com/lucawalz/.github/commit/1b0ba4f99da208a4576c2ef38933758e6f336f94))
* **tofu:** adopt horizon as released tier with open contributions ([d61cfb2](https://github.com/lucawalz/.github/commit/d61cfb2e387ff5ba5d2762ec4f74c81ce41a69ae))
* **tofu:** adopt the blog as deployed tier with discussions kept ([451b700](https://github.com/lucawalz/.github/commit/451b700ca458d9edb6bb6aa6674697ff736b5d07))
* **tofu:** adopt vigil into the released tier standard ([2ed797c](https://github.com/lucawalz/.github/commit/2ed797c70081664c9491078ccc2473572d30c562))


### Bug Fixes

* **codeql:** install the go version a repository declares before analysis ([8109f18](https://github.com/lucawalz/.github/commit/8109f185a8e64827c61b3d411b2c54576818094d))
* **renovate:** let docker images without release timestamps pass the age wait ([849d792](https://github.com/lucawalz/.github/commit/849d79296d80d9bfa9e7b19a42317f5467f398bf))
* **tofu:** import the ci label the labeler created on bedrock ([9f25164](https://github.com/lucawalz/.github/commit/9f251646542918fab1881b2d22d77a4487e50a4d))

## 0.1.0 (2026-11-18)


### Features

* **community:** add default community files and issue forms ([ad3a07b](https://github.com/lucawalz/.github/commit/ad3a07b3fb1fc772870a0cde6dc3aa6e4e2a7b5d))
* **release:** add shared release-please workflow with release comments ([fb0bd43](https://github.com/lucawalz/.github/commit/fb0bd433af0a64d90f635e264dfddfcbf3548ca5))
* **renovate:** add shared default preset for renovate managed repositories ([9406a64](https://github.com/lucawalz/.github/commit/9406a6444ee464ea3664209ae9632642fbec7780))
* **tofu:** manage repo settings with an opentofu standard module ([fe842dc](https://github.com/lucawalz/.github/commit/fe842dc1a9ef9255e095c43770a8ce4ce4581e9a))
* **workflows:** add shared scanning, pr title and automerge workflows ([969e37a](https://github.com/lucawalz/.github/commit/969e37a24222cbf75af26ad94aa74d043f6c42e1))


### Bug Fixes

* **ci:** raise dependabot cooldown and scan the whole repository ([ad2d3ba](https://github.com/lucawalz/.github/commit/ad2d3ba65396ee168de29bcc2e2764a04dfe0a36))
* **release:** publish drafts after assets and comment after publish ([1bcf484](https://github.com/lucawalz/.github/commit/1bcf4844cf86d31b0f803fe0b8aa17b7eac17e84))
* **release:** write the secrets guard as an if statement for shellcheck ([e8ded17](https://github.com/lucawalz/.github/commit/e8ded17950eb8cfdbca07ea009c42b035ff550f1))
* **tofu:** import the existing repository and labels before managing them ([148c2ea](https://github.com/lucawalz/.github/commit/148c2ea558ee243c073ca32100a16c5904a14f8b))
* **workflows:** publish scorecard results and time needs-info from the label ([ab90119](https://github.com/lucawalz/.github/commit/ab901192ea4b9e7f3e9e07377b1a99c792d79dd1))
