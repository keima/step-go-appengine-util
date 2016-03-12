# Go App Engine Deploy

A step that deploys Go applications to Google App Engine.

## Inspired by...

- [MiCHiLU/step-go-appengine-deploy](https://github.com/MiCHiLU/step-go-appengine-deploy)
- [grosinger/mac-and-cheese](https://github.com/tgrosinger/mac-and-cheese)

## Limitation

<del>
`$WERCKER_SOURCE_DIR`(gitのroot配下)もしくは`target-directory`オプション配下のディレクトリは、`$GOPATH`準拠になるようにしてください。
具体的には`/src`ディレクトリ内にgoファイルを配置するようにしてください。
加えて、上記ディレクトリ直下には`app.yaml`を含むようにしてください。
</del>

[v.0.1.0] `target-directory` attribute is deprecated. Please use `cwd` wercker built-in attribute. 

## Options

* `method` - `goapp` argument. Option is below. (required)
* `cwd` (wercker built-in) - change current directory to specified dir. (required if needed)
 - e.g. go source files are located in `/src/proj` and you'll do `goapp get`, set `cwd` to `/src/proj`.
 - e.g. app.yaml is located in `/` and you'll do `goapp deploy`, may not be set `cwd` to `/` because WERCKER_SRC is `/`.

### `deploy` method

#### Options

* `token` - The OAuth 2.0 refresh token of the Google account to use for deployment.

### `get` method

### `test` method

### `build` method

## Example

```
build:
  steps:
  - keima/go-appengine-util:
      cwd: path/to/gocode/
      method: get
  - keima/go-appengine-util:
      cwd: path/to/gocode/
      method: test
  - keima/go-appengine-util:
      cwd: path/to/gocode/
      method: build
deploy:
  steps:
  - keima/go-appengine-util:
      method: deploy
      cwd: path/to/appyaml/
      token:  $APP_ENGINE_TOKEN
```
