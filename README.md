# Go App Engine Deploy

A step that deploys Go applications to Google App Engine.

## Inspired by...

- [MiCHiLU/step-go-appengine-deploy](https://github.com/MiCHiLU/step-go-appengine-deploy)
- [grosinger/mac-and-cheese](https://github.com/tgrosinger/mac-and-cheese)

## Options

* `method` - `goapp` argument. Example is below. (required)
* `target-directory` - change current directory to dir of `app.yaml` is exists. (optional)

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
