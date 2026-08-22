# Pin npm packages by running ./bin/importmap
#
# chain-ops ships NO JavaScript today (no app/javascript, no vendor/javascript,
# no importmap tags in any view). This file exists so `bin/importmap audit` --
# the CI scan_js lane -- has an importmap to read instead of raising ENOENT.
# It audits an empty pin set now and starts auditing for real the moment the
# first `pin` lands here.
