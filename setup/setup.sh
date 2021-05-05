USERNAME="rht-jordisola"

MINIKUBE_DIR=$HOME"/.minikube"
CERT_DIRECTORY="$MINIKUBE_DIR/redhat-certs"
SCRIPTPATH="$( cd -- "$(dirname "$0")" >/dev/null 2>&1 ; pwd -P )"
MINIKUBE_CONTEXT=${USERNAME}-context
NAMESPACE_DEV=${USERNAME}-dev
NAMESPACE_STAGE=${USERNAME}-stage

function create_certificates() {
    echo "Creating certificates..."
    if [ ! -d $CERT_DIRECTORY ]; then
        mkdir $CERT_DIRECTORY
    fi

    cd $CERT_DIRECTORY
    openssl genrsa -out $USERNAME.key 2048 &> /dev/null
    openssl req -new -key $USERNAME.key -out $USERNAME.csr -subj "/CN=$USERNAME/O=group1" &> /dev/null
    openssl x509 -req -in $USERNAME.csr -CA $MINIKUBE_DIR/ca.crt -CAkey $MINIKUBE_DIR/ca.key -CAcreateserial -out $USERNAME.crt -days 500 &> /dev/null

    cp $USERNAME.key $MINIKUBE_DIR/$USERNAME.key
    cp $USERNAME.crt $MINIKUBE_DIR/$USERNAME.crt

}

function delete_namespace() {
    echo "Deleting namespace '${1}'..."
    if kubectl get namespace ${1} &> /dev/null ; then
        if ! kubectl delete namespace ${1} &> /dev/null ; then
            echo "Error while deleting namespace ${1}"
            exit
        fi
    fi
}

function create_namespace() {
    echo "Creating namespace '${1}'..."
    if ! kubectl get namespace ${1} &> /dev/null ; then
        if ! kubectl create namespace ${1} &> /dev/null ; then
            echo "Error while creating namespace ${1}"
            exit
        fi
    fi
}

function configure_kubectl_credentials() {
    echo "Creating Kubectl credentials ..."
    if ! kubectl config set-credentials $USERNAME --client-certificate=$USERNAME.crt --client-key=$USERNAME.key &> /dev/null ; then
        echo "Error while creating config credentials"
        exit
    fi
}
function create_kubectl_context() {
    echo "Creating Kubectl context for ${1} ..."
    if ! kubectl config set-context $MINIKUBE_CONTEXT --cluster=minikube --user=$USERNAME --namespace=${1} &> /dev/null; then
        echo "Error while creating config context"
        exit
    fi
}

function apply_role_resources() {

    if ! sed "s/{username}/${USERNAME}/g; s/{namespace}/${NAMESPACE_DEV}/g" $SCRIPTPATH/files/role-binding.yml | kubectl apply -f - &> /dev/null ; then
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

if [ "$1" == "--delete" ] || [ "$1" == "-d" ]; then

    kubectl config use-context minikube

    delete_namespace "${NAMESPACE_DEV}"
    delete_namespace "${NAMESPACE_STAGE}"

else 

    create_namespace "${NAMESPACE_DEV}"
    create_namespace "${NAMESPACE_STAGE}"

    create_certificates
    configure_kubectl_credentials

    create_kubectl_context "${NAMESPACE_DEV}"
    apply_role_resources "${NAMESPACE_DEV}"

    create_kubectl_context "${NAMESPACE_STAGE}"
    apply_role_resources "${NAMESPACE_STAGE}"

    if ! kubectl config use-context $MINIKUBE_CONTEXT &> /dev/null ; then
        echo "New context is not available"
        exit
    fi

fi
echo "OK!"
