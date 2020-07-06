#!/bin/sh

# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND,
# EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
# MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
# IN NO EVENT SHALL THE AUTHORS BE LIABLE FOR ANY CLAIM, DAMAGES OR
# OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE,
# ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR
# OTHER DEALINGS IN THE SOFTWARE.

HOST=10.254.2.3:8080
TLS_CERT=/lnd/tls.cert
LNDPASSWORD_PATH=/secrets/lnd-password.txt
MACAROON_PATH=/lnd/data/chain/bitcoin/mainnet/admin.macaroon

lncurl() {
	MACAROON="$(xxd -p /lnd/data/chain/bitcoin/mainnet/admin.macaroon | tr -d '\n')"
	url_path=$1
	data=$2

	curl  --fail  --silent  --show-error  \
	  --cacert "${TLS_CERT}"  \
	  --header "Grpc-Metadata-macaroon: ${MACAROON}"  \
	  --data "${data}"  \
	  "https://${HOST}/v1/${url_path}"
}

while true; do
	# First make sure that port is open
	while ! nc -z lnd 8080; do
		>&2 echo "Waiting for ${HOST} port to open…"
		sleep 3
	done
	>&2 echo "Port ${HOST} is open"

	# Wait a bit more in case the port was just opened
	sleep 1
	if [[ -f $LNDPASSWORD_PATH ]]; then
		if [[ -f $MACAROON_PATH ]]; then
			>&2 echo "Password and macaroon file file exists"
			PASS="$(cat /secrets/lnd-password.txt | tr -d '\n' | base64 | tr -d '\n')"
			UNLOCK_PAYLOAD="$(jq -nc --arg wallet_password ${PASS} '{$wallet_password}')"
			# Try getinfo then unlock
			>&2 echo "Trying ${HOST}/getinfo…"
			INFO=$(lncurl getinfo)
			if [ "$?" = "0" ]; then
				>&2 echo "Response: ${INFO}"
				alias="$(echo "${INFO}" | jq '.alias')"
				>&2 echo "Wallet for ${alias} unlocked!"
				exit 0
			fi
			>&2 echo "${HOST}/getinfo FAILED, out=${INFO}"

			>&2 echo "Trying ${HOST}/unlockwallet…"
			RESULT=$(lncurl unlockwallet "${UNLOCK_PAYLOAD}")
			>&2 echo "${HOST}/unlockwallet completed with: exit-code=$?, out=${RESULT}"
		else
			>&2 echo "macaroon file doesn't exist"
		fi
	else
		>&2 echo "password file doesn't exist"
	fi

	sleep 30
done
