USERNAME="student"
MINIKUBE_DIR=$HOME"/.minikube"
CERT_DIRECTORY="$MINIKUBE_DIR/redhat-certs"
SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"

function create_certificates() {
    echo "Creating certificates..."
    if [ ! -d $CERT_DIRECTORY ]; then
        mkdir $CERT_DIRECTORY
    fi

    cd $CERT_DIRECTORY
    openssl genrsa -out $USERNAME.key 2048 &> /dev/null
    openssl req -new -key $USERNAME.key -out $USERNAME.csr -subj "/CN=$USERNAME/O=group1" &> /dev/null
    openssl x509 -req -in $USERNAME.csr -CA $MINIKUBE_DIR/ca.crt -CAkey $MINIKUBE_DIR/ca.key -CAcreateserial -out $USERNAME.crt -days 500 &> /dev/null
}

function create_namespace() {
    echo "Creating namespace 'redhat-test'..."
    if ! kubectl get namespace redhat-test &> /dev/null ; then
        if ! kubectl create namespace redhat-test &> /dev/null ; then
            echo "Error while creating namespace"
            exit
        fi
    fi
}

function configure_kubectl_credentials() {
    echo "Creating Kubectl credentials and context..."
    if ! kubectl config set-credentials $USERNAME --client-certificate=$USERNAME.crt --client-key=$USERNAME.key &> /dev/null ; then
        echo "Error while creating config credentials"
        exit
    fi

    if ! kubectl config set-context $USERNAME-context --cluster=minikube --user=$USERNAME --namespace=redhat-test &> /dev/null; then
        echo "Error while creating config context"
        exit
    fi
}

function apply_role_resources() {
    if ! kubectl apply -f $SCRIPTPATH/files/role.yml &> /dev/null ; then
        echo "Could not apply Role resource"
        exit
    fi

    if ! kubectl apply -f $SCRIPTPATH/files/role-binding.yml &> /dev/null ; then
        echo "Could not apply RoleBinding resource"
        exit
    fi
}

if ! command -v openssl &> /dev/null
then
    echo "Please install OpenSSL"
    exit
fi

if ! command -v kubectl &> /dev/null
then
    echo "Please install Kubectl"
    exit
fi

if [ ! -d $MINIKUBE_DIR ]; then
    echo "Minikube directory not found"
    exit
fi

if ! kubectl config use-context minikube &> /dev/null ; then
    echo "Minikube context is not available"
    exit
fi

create_namespace
create_certificates
configure_kubectl_credentials
apply_role_resources

if ! kubectl config use-context $USERNAME-context &> /dev/null ; then
    echo "New context is not available"
    exit
fi

cp $USERNAME.key $MINIKUBE_DIR/$USERNAME.key
cp $USERNAME.crt $MINIKUBE_DIR/$USERNAME.crt

echo "OK!"