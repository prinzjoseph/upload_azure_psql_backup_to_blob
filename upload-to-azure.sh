#!/usr/bin/env bash

TIME=`date +%b-%d-%y`
FILENAME=postgresqprod-$TIME.sql
AZURE_STORAGE_ACCOUNT=<accout_name>
AZURE_CONTAINER_NAME=<container_name>
AZURE_ACCESS_KEY=<azure_access_key>

export PGPASSWORD='password'; PGSSLMODE=allow pg_dump --host=host --port=port --username=user --dbname=db > $FILENAME

authorization="SharedKey"

HTTP_METHOD="PUT"
request_date=$(TZ=GMT date "+%a, %d %h %Y %H:%M:%S %Z")
storage_service_version="2015-02-21"

# HTTP Request headers
x_ms_date_h="x-ms-date:$request_date"
x_ms_version_h="x-ms-version:$storage_service_version"
x_ms_blob_type_h="x-ms-blob-type:BlockBlob"

FILE_LENGTH=$(wc --bytes < ${FILENAME})
FILE_TYPE=$(file --mime-type -b ${FILENAME})

# Build the signature string
canonicalized_headers="${x_ms_blob_type_h}\n${x_ms_date_h}\n${x_ms_version_h}"
canonicalized_resource="/${AZURE_STORAGE_ACCOUNT}/${AZURE_CONTAINER_NAME}/${FILENAME}"

string_to_sign="${HTTP_METHOD}\n\n\n${FILE_LENGTH}\n\n${FILE_TYPE}\n\n\n\n\n\n\n${canonicalized_headers}\n${canonicalized_resource}"

# Decode the Base64 encoded access key, convert to Hex.
decoded_hex_key="$(echo -n $AZURE_ACCESS_KEY | base64 -d -w0 | xxd -p -c256)"

# Create the HMAC signature for the Authorization header
signature=$(printf  "$string_to_sign" | openssl dgst -sha256 -mac HMAC -macopt "hexkey:$decoded_hex_key" -binary | base64 -w0)

authorization_header="Authorization: $authorization $AZURE_STORAGE_ACCOUNT:$signature"
OUTPUT_FILE="https://${AZURE_STORAGE_ACCOUNT}.blob.core.windows.net/${AZURE_CONTAINER_NAME}/${FILENAME}"

curl -X ${HTTP_METHOD} \
    -T ${FILENAME} \
    -H "$x_ms_date_h" \
    -H "$x_ms_version_h" \
    -H "$x_ms_blob_type_h" \
    -H "$authorization_header" \
    -H "Content-Type: ${FILE_TYPE}" \
    ${OUTPUT_FILE}

if [ $? -eq 0 ]; then
    echo ${OUTPUT_FILE}
    #removing backup file from vm
    rm -rf $FILENAME
    exit 0;
fi;

exit 1
