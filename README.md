
## setup (optional)

1. create private ca
```
openssl genrsa 2048 > ca-key.pem
openssl req -new -sha256 -key ca-key.pem -nodes -out ca.csr -config ca.conf
openssl x509 -req -in ca.csr -signkey ca-key.pem -days 10000 -out ca.crt -extfile ca.conf -extensions v3_ca

```
2. create client certificate
```
openssl genrsa 2048 > client-key.pem
openssl req -new -key client-key.pem -config csr.conf -out client.csr
openssl x509 -req -in client.csr -CA ca.crt -CAkey ca-key.pem -CAcreateserial -days 9000 -out client.crt -extfile csr.conf -extensions v3_ext

```

## aws 
### setup
create public hosted zone

### check

1. move direcotry
```
cd aws
```
2. terraform init
```
terraform init
```
3. terraform apply

require public hosted zone name
```
terraform apply
```
4. test
```
curl -v  https://mtls-tst.<public_domain>
curl -v  https://mtls-tst.<public_domain> --key ../client-key.pem --cert ../client.crt
```

## gcp
### setup
create public hosted zone

### check

1. move direcotry
```
cd aws
```
2. terraform init
```
terraform init
```
3. terraform apply

require public hosted zone name, project id
```
terraform apply
```
4. test
```
curl -v  https://mtls-tst.<public_domain>/
curl -v  https://mtls-tst.<public_domain>/ --key ../client-key.pem --cert ../client.crt
```
