#!/bin/bash -e

export RUST_BACKTRACE=1

function pw() {
    echo asdf | cargo run -- -u pw-test-user -q "$@"
}

function cleanup() {
    if [ -n "$TRAVIS" ]; then
        return;
    fi
    cargo run -- -u pw-test-user --delete-keyring-password
    cargo run -- -u pw-test-user --delete-keyring-config
}
trap cleanup EXIT HUP INT TERM

set -x

# test -d with a hand computed password
[ "$(pw -r 180 zomg -d 2017-11-22)" = "LiV3cQBO0h" ]

# test -r doesn't change too early
for i in $(seq 1 10); do
    [ "$(pw -r 10 zomg -d 2010-01-$i)" = "SQKt9Zgyyd" ]
done
[ "$(pw -r 10 zomg -d 2010-01-11)" = "CJ18ePduQ2" ]

# test changing -r changes things
[ "$(pw -r 10 zomg)" != "$(pw -r 20 zomg)" ]

# test -o
[ "$(pw zomg)" = "oXU35wO56X" ]
[ "$(pw -o 0 zomg)" = "oXU35wO56X" ]
[ "$(pw -o 1 zomg)" = "Kr54O/5mh7" ]
[ "$(pw -o 2 zomg)" = "i24SkBFkm4" ]

# test -s
[ "$(pw zomg -s)" = "XU35wO56X^" ]

# test -l
[ "$(pw -l 20 zomg)" = "oXU35wO56XLbISexn4pT" ]

# test -l -s
[ "$(pw zomg -l 20 -s)" = "XU35wO56XLbISexn4pT{" ]

# test otp config fallback
[ "$(pw -f ./test.toml zomg)" = "Kr54O/5mh7" ]
[ "$(pw -f ./test.toml zomg -o 2)" = "i24SkBFkm4" ]

# test --question
[ "$(pw zomg --question "Do you like trees?")" = "H/zJqV24Gb" ]

# test preshared config option
[ "$(pw zomg -f ./preshared.toml)" = "o+uxxezJBT" ]


# Below here we can't test on travis, because it doesn't have secretservice.
if [ -n "$TRAVIS" ]; then
    exit 0
fi

pw --set-keyring-password
[ "$(pw --get-keyring-password)" == "asdf" ]

# explicitly use cargo run, so we can be sure to bypass entering the password
[ "$(cargo run -- zomg)" = "oXU35wO56X" ]

# test that we don't mutliate the config
pw --set-keyring-config ./keyring.toml
pw --get-keyring-config ./from_keyring.toml
[ "$(sha256sum ./keyring.toml | cut -f1 -d" ")" == "$(sha256sum ./from_keyring.toml | cut -f1 -d" ")" ]

# now test that we got the right otp=1 password from the keyring config
[ "$(pw zomg)" = "Kr54O/5mh7" ]
