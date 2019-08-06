---
title: "gin搭建webServer自动部署github项目"
date: 2019-05-09 15:56
tag: 
  - go
  - gin
---

[TOC]

## gin use

自动部署项目

### Web hooks干嘛用的？

> Github Webhooks提供了一堆事件，这些事件在用户特定的操作下会被触发，比如创建分支(Branch)、库被fork、项目被star、用户push了代码等等。 我们可以自己写一个服务,将服务的URL交给Webhooks，当上述事件被触发时，Webhook会向这个服务发送一个POST请求，请求中附带着该事件相关的详细描述信息(即Payload)。 这样，我们就可以在自己服务中知道Github的什么事件被触发了，事件的内容是什么？据此我们就可以干一些自己想干的事了。能干什么呢？官方说You're only limited by your imagination，就是说想干什么都行，就看你的想像力够不够 :)

> 当指定的事件发生时，我们将向您提供的每个URL发送POST请求。通过这个post请求，我们就能实现自动拉取仓库中的代码，更新到本地，最终实现自动化更新

### web Hook Post

![img](images/XHSign.jpg)

- Request URL

即前面配置中填写的"Payload URL"

- content-type

即前面配置中选择的"Content type"

- X-Hub-Signature

是对Payload计算得出的签名。当我们在前面的配置中输入了"Secret"后，Header中才会出现此项。官方文档对Secret作了详细说明，后面我们也会在代码中实现对它的校验

```cgo
1. 监听端口port:8000,监听的uri路径path,运行部署脚本sh,webhook的secret,
2. 使用-p 指定端口,使用-path 指定uri路径,使用-sh 指定运行脚本, 使用-s 指定密码,
3. 原理是通过webhook的Post,来校验sha1,通过校验则执行部署脚本
```

### 源码实现

源码如下

```
package main

import (
	"crypto/hmac"
	"crypto/sha1"
	"encoding/hex"
	"flag"
	"fmt"
	"github.com/gin-gonic/gin"
	"io"
	"log"
	"net/http"
	"os"
	"os/exec"
)

var (
	secret string
	port   string
	path   string
	shell  string
	h      bool
)

// return true then deploy
func gitPush(c *gin.Context) {
	matched, _ := verifySignature(c)
	if !matched {
		err := "Signatures did not match"
		c.String(http.StatusForbidden, err)
		fmt.Println(err)
		return
	}
	fmt.Println("Signatures is matched ~")
	c.String(http.StatusOK, "OK")
	ReLaunch()
}

// execute the shell scripts
func ReLaunch() {
	cmd := exec.Command("sh", shell)
	err := cmd.Start()
	if err != nil {
		log.Fatal(err.Error())
	}
	err = cmd.Wait()
}

// verifySignature
func verifySignature(c *gin.Context) (bool, error) {
	PayloadBody, err := c.GetRawData()
	if err != nil {
		return false, err
	}
	// Get Header with X-Hub-Signature
	XHubSignature := c.GetHeader("X-Hub-Signature")
	signature := getSha1Code(PayloadBody)
	fmt.Println(signature)
	return XHubSignature == signature, nil
}

// hmac-sha1
func getSha1Code(payloadBody []byte) string {
	h := hmac.New(sha1.New, []byte(secret))
	h.Write(payloadBody)
	return "sha1=" + hex.EncodeToString(h.Sum(nil))
}

func usage()  {
	_, _ = fmt.Fprintf(os.Stderr, `deploy version: deploy:1.0.5
Usage: deploy [-p port] [-path UriPath] [-sh DeployShell] [-pwd WebhookSecret]

Options:
`)
	flag.PrintDefaults()
}

func init() {
	// use flag to change args
	flag.StringVar(&port, "p", "8000", "listen and serve port")
	flag.StringVar(&secret, "pwd", "hongfeng", "deploy password")
	flag.StringVar(&path, "path", "/deploy/wiki", "uri serve path")
	flag.StringVar(&shell, "sh", "/app/wiki.sh", "deploy shell scritpt")
	flag.BoolVar(&h, "h", false, "show this help")
	flag.Usage = usage
}

func main() {
	flag.Parse()
	if h {
		flag.Usage()
		return
	}
	// Disable Console Color, you don't need console color when writing the logs to file
	gin.DisableConsoleColor()
	// Logging to a file.
	f, _ := os.Create("/logs/gin.log")
	gin.DefaultWriter = io.MultiWriter(f)
	// Use the following code if you need to write the logs to file and console at the same time.
	// gin.DefaultWriter = io.MultiWriter(f, os.Stdout)

	router := gin.Default()
	router.GET(path, gitPush)
	_ = router.Run(":" + port)
}
```

[github](https://github.com/oldthreefeng/ginuse)

- how to use

```
##1. clone 
$ git clone https://github.com/oldthreefeng/ginuse
##2. bulid
$ cd ginuse  && go run deploy.go
## 3. run
## windows
deploy.exe -h
deploy version: deploy:1.0.5
Usage: deploy [-p port] [-path UriPath] [-sh DeployShell] [-pwd WebhookSecret]

Options:
  -h	show this help
  -p string
    	listen and serve port (default "8000")
  -path string
    	url serve path (default "/deploy/wiki")
  -pwd string
    	deploy password (default "hongfeng")
  -sh string
    	deploy shell scritpt (default "/app/wiki.sh")
    	
## linux
deploy -h
deploy version: deploy:1.0.5
Usage: deploy [-p port] [-path UriPath] [-sh DeployShell] [-pwd WebhookSecret]

Options:
  -h	show this help
  -p string
    	listen and serve port (default "8000")
  -path string
    	url serve path (default "/deploy/wiki")
  -pwd string
    	deploy password (default "hongfeng")
  -sh string
    	deploy shell scritpt (default "/app/wiki.sh")
```

练手的go项目,学习`golang`第15天~