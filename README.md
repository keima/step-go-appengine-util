# Go App Engine Deploy

A step that deploys Go applications to Google App Engine.

## Inspired by...

- [MiCHiLU/step-go-appengine-deploy](https://github.com/MiCHiLU/step-go-appengine-deploy)
- [grosinger/mac-and-cheese](https://github.com/tgrosinger/mac-and-cheese)

## Limitation

`$WERCKER_SOURCE_DIR`(gitのroot配下)もしくは`target-directory`オプション配下のディレクトリは、`$GOPATH`準拠になるようにしてください。
具体的には`/src`ディレクトリ内にgoファイルを配置するようにしてください。
加えて、上記ディレクトリ直下には`app.yaml`を含むようにしてください。

## Options

* `method` - `goapp` argument. Example is below. (required)
* `target-directory` - change current directory to specified dir.
 - e.g. go source files are located in `/src/proj` and do `goapp get`, set `target-directory` to `/src/proj`
 - e.g. app.yaml is located in `/` and do `goapp deploy`, may not be set `target-directory` to `/`

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
      target-directory: path/to/appyaml/
      method: get
  - keima/go-appengine-util:
      target-directory: path/to/appyaml/
      method: test
  - keima/go-appengine-util:
      target-directory: path/to/appyaml/
      method: build
deploy:
  steps:
  - keima/go-appengine-util:
      method: deploy
      target-directory: path/to/appyaml/
      token:  $APP_ENGINE_TOKEN
```
