---
title: "go module"
date: 2019-08-28 18:10
tag: 
  - mod
---

[TOC]

### use go module

```
$ cat main.go
/*
@Time : 2019/9/8 1:35
@Author : louis
@File : main
@Software: GoLand
*/

package main

import  log "github.com/Sirupsen/logrus"

func main()  {
        log.Info("this is a log log")
        log.Warn("this is an another log log")
        log.Fatal("this a bad log")
}
```
如果没有modules,安装依赖需要一个一个`go get ...`

```
$ go run main.go
go: github.com/Sirupsen/logrus: github.com/Sirupsen/logrus@v1.4.2: parsing go.mod:
        module declares its path as: github.com/sirupsen/logrus
                but was required as: github.com/Sirupsen/logrus
```

当我们使用`go mod`的时候,只需要init一下就好,但是必须在`$GOAPTH`下面,而且`GO111MODULES=on`.

```

$ go mod init

$ go run main.go
time="2019-09-08T02:16:46+08:00" level=info msg="this is a log log"
time="2019-09-08T02:16:46+08:00" level=warning msg="this is an another log log"
time="2019-09-08T02:16:46+08:00" level=fatal msg="this a bad log"
exit status 1

$ go mod tidy
go: downloading golang.org/x/sys v0.0.0-20190422165155-953cdadca894
go: downloading github.com/stretchr/testify v1.2.2
go: extracting github.com/stretchr/testify v1.2.2
go: extracting golang.org/x/sys v0.0.0-20190422165155-953cdadca894

$ go mod vendor

$ ls
go.mod  go.sum  main.go  readme.md  vendor/


$ cat go.sum
github.com/davecgh/go-spew v1.1.1 h1:vj9j/u1bqnvCEfJOwUhtlOARqs3+rkHYY13jYWTU97c=
github.com/davecgh/go-spew v1.1.1/go.mod h1:J7Y8YcW2NihsgmVo/mv3lAwl/skON4iLHjSsI+c5H38=
github.com/konsorten/go-windows-terminal-sequences v1.0.1 h1:mweAR1A6xJ3oS2pRaGiHgQ4OO8tzTaLawm8vnODuwDk=
github.com/konsorten/go-windows-terminal-sequences v1.0.1/go.mod h1:T0+1ngSBFLxvqU3pZ+m/2kptfBszLMUkC4ZK/EgS/cQ=
github.com/pmezard/go-difflib v1.0.0 h1:4DBwDE0NGyQoBHbLQYPwSUPoCMWR5BEzIk/f1lZbAQM=
github.com/pmezard/go-difflib v1.0.0/go.mod h1:iKH77koFhYxTK1pcRnkKkqfTogsbg7gZNVY4sRDYZ/4=
github.com/sirupsen/logrus v1.4.2 h1:SPIRibHv4MatM3XXNO2BJeFLZwZ2LvZgfQ5+UNI2im4=
github.com/sirupsen/logrus v1.4.2/go.mod h1:tLMulIdttU9McNUspp0xgXVQah82FyeX6MwdIuYE2rE=
github.com/stretchr/objx v0.1.1/go.mod h1:HFkY916IF+rwdDfMAkV7OtwuqBVzrE8GR6GFx+wExME=
github.com/stretchr/testify v1.2.2 h1:bSDNvY7ZPG5RlJ8otE/7V6gMiyenm9RtJ7IUVIAoJ1w=
github.com/stretchr/testify v1.2.2/go.mod h1:a8OnRcib4nhh0OaRAV+Yts87kKdq0PP7pXfy6kDkUVs=
golang.org/x/sys v0.0.0-20190422165155-953cdadca894 h1:Cz4ceDQGXuKRnVBDTS23GTn/pU5OE2C0WrNTOYK1Uuc=
golang.org/x/sys v0.0.0-20190422165155-953cdadca894/go.mod h1:h1NjWce9XRLGQEsW7wpKNCjG9DtNlClVuFLEZdDNbEs=
```
当我们想知道`go.sum`里面为什么会有这个依赖的时候,就可以利用`why`这个flag来进行查询了

```
$ go mod why github.com/davecgh/go-spew
# github.com/davecgh/go-spew
(main module does not need package github.com/davecgh/go-spew)

$ go mod why -m github.com/davecgh/go-spew
# github.com/davecgh/go-spew
gogs.wangke.co/go/algo/gomod
github.com/sirupsen/logrus
github.com/sirupsen/logrus.test
github.com/stretchr/testify/assert
github.com/davecgh/go-spew/spew

```

简单的用法就说到这里~

