VERSION=0.0.1
php: php/5.6.9

php/5.6.9:
	docker run --rm -w /binary-builder -v `pwd`:/binary-builder -it pepabo/cnb:cflinuxfs3 ./bin/binary-builder --name=php --version=5.6.9 --sha256=49527ba66357fe65bcd463dfb8dcff1b8879419f88b3c334f50696a2aceacb87 --php-extensions-file=./php5-extensions.yml


build_image:
	docker build -t pepabo/cnb:cflinuxfs3 .

push_image:
	docker push pepabo/cnb:cflinuxfs3
rebase:
	git remote add cf https://github.com/cloudfoundry/binary-builder.git | true
	git fetch cf
	git merge cf/master

release:
	ghr -replace v$(VERSION) *tgz
