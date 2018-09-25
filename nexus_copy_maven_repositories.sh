#!/bin/bash
#
#
#  Copy repository artifacts from Nexus 3 to another Nexus 3 instance
#  Run this on the source Nexus 3 machine and make sure the repository already exists on the target
#  Prerequisites: curl, jq, wget
#
#                      "If it looks stupid but it works, it ain't stupid."
#
#####################################################################################################
#
#
# Beware: the api from nexus 3.12 to 3.13 had changed from /rest/beta to /rest/v1
#
# Example
#
# sh nexus_copy_artifacts.sh -h localhost -P <port e.g. 8081> -u <source/local user> -p <source/local password> -H <target hostname> -U <target user> -W <target pass> -r <repository>
#
set +x -e

# Define opts
while getopts h:P:u:p:r:H:U:W:t: option
do
case "${option}"
in
h) HOST=${OPTARG};;
P) PORT=${OPTARG};;
u) USER=${OPTARG};;
p) PASSWORD=${OPTARG};;
r) REPO=${OPTARG};;
H) TARGET_HOST=${OPTARG};;
U) TARGET_HOST_USER=${OPTARG};;
W) TARGET_HOST_PASSWORD=${OPTARG};;
t) REPO_TYPE=${OPTARG};;
esac
done


function postMvnComponent {
    #waaaah - y u no working!?
    mvnGroupId=${1}
    mvnArtifactId=${2}
    mvnVersion=${3}
    mvnPackaging=${4}
    numberOfFiles=${5}  #notinuse
    listOfFiles="${6}"

    echo "curl -X POST -u ${TARGET_HOST_USER}:\"${TARGET_HOST_PASSWORD}\" \"https://${TARGET_HOST}/service/rest/v1/components?repository=${REPO}\"
         -H \"accept: application/json\" \
         -H \"Content-Type: multipart/form-data\" \
         -F \"maven2.groupId=${mvnGroupId}\" \
         -F \"maven2.artifactId=${mvnArtifactId}\" \
         -F \"maven2.version=${mvnVersion}\" \
         -F \"maven2.generate-pom=false\" \
         -F \"maven2.packaging=${mvnPackaging}\" \
         ${filepathWithArgs}"


    curl -X POST -u ${TARGET_HOST_USER}:"${TARGET_HOST_PASSWORD}" "https://${TARGET_HOST}/service/rest/v1/components?repository=${REPO}" -H "accept: application/json" -H "Content-Type: multipart/form-data" -F "maven2.groupId=${mvnGroupId}" -F "maven2.artifactId=${mvnArtifactId}"  -F "maven2.version=${mvnVersion}" -F "maven2.generate-pom=false"  -F "maven2.packaging=${mvnPackaging}" "${filepathWithArgs}"
     exitcode=$?

    return ${exitcode}
    #curl -X POST "https://t1p-nexus.t1p-cc.aws.route71.net/service/rest/v1/components?repository=android-releases" -H "accept: application/json" -H "Content-Type: multipart/form-data" -F "maven2.groupId=de.maxdome.app" -F "maven2.artifactId=app" -F "maven2.version=13.3.7" -F "maven2.generate-pom=true" -F "maven2.packaging=apk" -F "maven2.asset1=@gapp-13.3.7-prodCompatRelease.apk;type=application/vnd.android.package-archive" -F "maven2.asset1.extension=apk" -F "maven2.asset2=@gapp-13.3.7-internalCompatRelease.apk;type=application/vnd.android.package-archive" -F "maven2.asset2.extension=apk" -F "maven2.asset3=@gapp-13.3.7.pom;type="
}

function mvnPublishFile {
    echo "<settings><servers><server><id>nexus</id><username>${TARGET_HOST_USER}</username><password>${TARGET_HOST_PASSWORD}</password></server></servers></settings>" > ~/.m2/settings.xml

    mvnGroupId="${1}"
    mvnArtifactId="${2}"
    mvnVersion="${3}"
    mvnPackaging="${4}"
    numberOfFiles="${5}"  #notinuse
    listOfFiles="${6}" #komma separated
    classifiers="${7}" #komma separated
    pomFile="${8}"

    fileArgs=""
    if [ -z ${classifiers} ]; then
        for pathToFile in $(echo ${listOfFiles} |tr -d "," ); do
            fileArgs="${fileArgs} -Dfile=${pathToFile}"
        done
    elif [ ${classifiers} = "null" ]; then
        for pathToFile in $(echo ${listOfFiles} |tr -d "," ); do
            fileArgs="${fileArgs} -Dfile=${pathToFile}"
        done
    else
        fileArgs="-Dfiles=${listOfFiles} -Dclassifiers=${classifiers}"
    fi

    #maybe just one file
    if [ -z ${pomFile} ]; then
        echo "mvn deploy:deploy-file -Durl=https://${TARGET_HOST}/repository/${REPO} -DgeneratePom=false -DartifactId=${mvnArtifactId} -Dversion=${mvnVersion} -DgroupId=${mvnGroupId} -DartifactId=${mvnArtifactId} -DrepositoryId=nexus ${fileArgs}"
        mvn deploy:deploy-file -Durl=https://${TARGET_HOST}/repository/${REPO} -DgeneratePom=false -DartifactId=${mvnArtifactId} -Dversion=${mvnVersion} -DgroupId=${mvnGroupId} -DartifactId=${mvnArtifactId} -DrepositoryId=nexus ${fileArgs}
        exitcode=$?

#    #maybe pom and one file
#    elif [ ${classifiers} == "null" ]; then
#        echo "mvn deploy:deploy-file -Durl=https://${TARGET_HOST}/repository/${REPO} -DgeneratePom=false -DartifactId=${mvnArtifactId} -Dversion=${mvnVersion} -DgroupId=${mvnGroupId} -DartifactId=${mvnArtifactId} -DrepositoryId=nexus -DpomFile=${pomFile} ${fileArgs}"
#        mvn deploy:deploy-file -Durl=https://${TARGET_HOST}/repository/${REPO} -DgeneratePom=false -DartifactId=${mvnArtifactId} -Dversion=${mvnVersion} -DgroupId=${mvnGroupId} -DartifactId=${mvnArtifactId} -DrepositoryId=nexus -DpomFile=${pomFile} ${fileArgs}
    else
        echo "mvn deploy:deploy-file -Durl=https://${TARGET_HOST}/repository/${REPO} -DgeneratePom=false -DartifactId=${mvnArtifactId} -Dversion=${mvnVersion} -DgroupId=${mvnGroupId} -DartifactId=${mvnArtifactId} -DrepositoryId=nexus -DpomFile=${pomFile} ${fileArgs}"
        mvn deploy:deploy-file -Durl=https://${TARGET_HOST}/repository/${REPO} -DgeneratePom=false -DartifactId=${mvnArtifactId} -Dversion=${mvnVersion} -DgroupId=${mvnGroupId} -DartifactId=${mvnArtifactId} -DrepositoryId=nexus -DpomFile=${pomFile} ${fileArgs}
        exitcode=$?
    fi
    if [ ${exitcode} -ne 0 ]; then
        echo "FAILED TO migrate: ${mvnArtifactId} ${mvnGroupId}-${mvnVersion}" >>./failed2bemigrated-${REPO}.txt
    fi
    return ${exitcode}
}

function fileIsChecksum {
    filenameString=${1}
    if [[ ${filenameString} =~ (\.md5|\.sha1)$ ]]; then
        echo 1
    elif [[ ! ${filenameString} =~ (\.md5|\.sha1)$ ]]; then
        echo 0
    #else
    #    echo "ERROR: unable to match for checksum-file"
    fi

}

function downloadFile {
    componentid=${1}
    url=${2}
    wget -4 -q --cut-dirs=2 -nH -x -P ./assets/${componentid} ${url}
}

function cleanup {
    echo "INFO: cleanup function started"
    files_to_be_deleted="temp_file.json this_component.json all_items_in_${REPO}.txt ./assets ~/.m2/settings.xml ./failed2bemigrated-${REPO}.txt"
    echo "Migration failures for Repository ${REPO}"
    cat ./failed2bemigrated-${REPO}.txt
    for file_or_folder in $(echo ${files_to_be_deleted}); do
        if [ -e ${file_or_folder} ]; then
            echo "INFO: ${file_or_folder} exists... deleting4cleanup"
            rm -rf ${file_or_folder}
        else
            echo "WARN: ${file_or_folder} is not existing. unable to cleanup"
        fi
    done
}


#initial api request to gather all component IDs

#echo "debug: Host https://${HOST}:${PORT}"
curl -s -X GET -u ${USER}:"${PASSWORD}" "http://${HOST}:${PORT}/service/rest/beta/components?repository=${REPO}" -H "accept: application/json" > temp_file.json
CONTINUATION_TOKEN=$(cat temp_file.json | jq -r '.continuationToken')
#echo "debug: INITIAL CONTINUATION_TOKEN: ${CONTINUATION_TOKEN}"

#NUMBER_OF_ITEMSs=$(cat temp_file.json | jq -r '.items[].id'| wc -l)
#echo "NUMBER_OF_ITEMSs: ${NUMBER_OF_ITEMSs}"

ITEMS=$(cat temp_file.json | jq -r '.items[].id')
echo "${ITEMS}" > all_items_in_${REPO}.txt


while [ ! -z ${CONTINUATION_TOKEN} -a ${CONTINUATION_TOKEN} != "null" ]; do
        curl -s -X GET u ${USER}:"${PASSWORD}" "http://${HOST}:${PORT}/service/rest/beta/components?continuationToken=${CONTINUATION_TOKEN}&repository=${REPO}" -H "accept: application/json" > temp_file.json
        CONTINUATION_TOKEN=$(cat temp_file.json | jq -r '.continuationToken')
#       echo "debug: CONTINUATION_TOKEN: ${CONTINUATION_TOKEN}"

        ITEMS=$(cat temp_file.json | jq -r '.items[].id')
        echo "${ITEMS}" >> all_items_in_${REPO}.txt

done
echo "INFO: FINISHED gathering all component IDs for maven Repo ${REPO} in $(pwd)/all_items_in_${REPO}.txt"


#gather all assets for ID
for componentID in $(cat all_items_in_${REPO}.txt); do
#    echo "debug: componentID ${componentID}"
    curl -s -X GET -u ${USER}:"${PASSWORD}" "http://${HOST}:${PORT}/service/rest/beta/components/${componentID}" -H "accept: application/json" > this_component.json

    #extract component metadata
    searchstr=".id"
    this_item_id=$(cat this_component.json | jq -r "${searchstr}")
#    echo "debug: this_item_id: ${this_item_id}"
#    echo "debug: componentID ${componentID}"
#    echo "debug: versus      ${this_item_id}"

    searchstr=".group"
    this_group=$(cat this_component.json | jq -r "${searchstr}")
#    echo "debug: this_group: ${this_group}"

    searchstr=".name"
    this_name=$(cat this_component.json | jq -r "${searchstr}")
#    echo "debug: this_name: ${this_name}"

    searchstr=".version"
    this_version=$(cat this_component.json | jq -r "${searchstr}")
#   echo "debug: this_version: ${this_version}"


    #extract downloadURLs
    searchstr=".assets[].downloadUrl"
    this_downloadurls=$(cat this_component.json | jq -r "${searchstr}")
#    echo "debug: this_downloadurl: ${this_downloadurls}"
    thisDownloadUrlCounted=$(echo ${this_downloadurls}|wc -l)

    #extract path
    searchstr=".assets[].path"
    this_paths=$(cat this_component.json | jq -r "${searchstr}")
    this_pathsCounted=$(echo ${this_paths}|wc -l)
    mkdir -p ./assets/${componentID}

    #echo "this_paths: ${this_paths}"

    filepathWithArgs=""
    counter=1
    packaging=""
    classifier=""
    mvnFilelist=""    #only for mvn
    mvnClassifiers="" #only for mvn
    mvnFiles=""       #only for mvn - for classifiers
    mvnPomfile=""     #only for mvn
    #Formulardaten zusammenbauen und dateien runterladen
    for i in $(echo -e ${this_paths}); do
        #echo "doing File: ${i}"
        #detect wether md5sum-file or sha-file and leave out
        if [[ ${i} =~ (\.md5$|\.sha1$) ]]; then
            #echo "debug: md5sumfile detected: ${i}"
            continue
        fi

        downloadFile ${componentID} "http://${HOST}:${PORT}/repository/${REPO}/${i}"
        #detect wether pom or not (if so extract <packaging> tag)
        if [[ ${i} =~ (\.pom$) ]]; then
            packaging=$(xmllint --xpath "/*[name()='project']/*[name()='packaging']/text()" $(find ./assets/${componentID}/ -type f -name "*.pom"))
            filepathWithArgs="${filepathWithArgs}-F \"maven2.asset${counter}=@./assets/${componentID}/${i}\" "
            mvnPomfile="./assets/${componentID}/${i}"
            ((counter++))
            continue
        fi

        # this_groupSlash=$(echo ${this_group} | sed -s/\./\//g)
        # regexBefore="${this_groupSlash}/${this_name}/${this_version}/${this_name}-${this_version}-"
        # regexAfter=""
        #inbetween Classifier

        #extract classifeier

        classifier="$(echo -e ${i} | awk -F '/' '{print $NF}'|sed "s/${this_name}-${this_version}[-]*//" | sed "s/\....$//" )"
        echo "classifier ${classifier}"
        #this one is needed for curl-upload
        #if [ ! -z ${classifier} ]; then
        #    filepathWithArgs="${filepathWithArgs}-F \"maven2.asset${counter}.classifier=${classifier}\" "
        #fi
        #this part is for mvn
        #echo "mvnClassifiers: ${mvnClassifiers}"
        if [ "${mvnClassifiers}" = "null" ]; then
            echo "You should not come here. mvnClassifiers ${mvnClassifiers} matches for string 'null'"
            echo "This means: either there is already a file or this Component has no classifiers"
            echo "componentID: ${componentID}"
            echo "Exiting..."
            exit 1
        elif [ -z "${mvnClassifiers}" -a -z "${classifier}" ]; then
            #case: classifiers befor were not extracted before and now extraction brought zero length
            mvnClassifiers="null"
        elif [ "${mvnClassifiers}" = "null" -a -z "${classifier}" ]; then
            #case: classifiers before brought zero and now no classifier was extracted
            mvnClassifiers="null"
        elif [ ! -z "${mvnClassifiers}" -a -z "${classifier}" ]; then
            echo "You should not come here. mvnClassifiers ${mvnClassifiers} does not match for string 'null' but classifier ${classifier} has zero length"
            echo "This means: either there is already a file or this Component has no classifiers"
            echo "componentID: ${componentID}"
            echo "Exiting..."
            exit 1
        elif [ -z "${mvnClassifiers}" -a ! -z "${classifier}" ]; then
            mvnClassifiers="${classifier}"
            if [ -z ${mvnFiles} ]; then
                mvnFiles="./assets/${componentID}/${i}"
            else
                mvnFiles="${mvnFiles},./assets/${componentID}/${i}"
            fi
        else
            mvnClassifiers="${mvnClassifiers},${classifier}"
            mvnFiles="${mvnFiles},./assets/${componentID}/${i}"
        fi



        dateiendung="$(echo -e ${i} | rev |cut -d "/" -f 1|rev|sed "s/${this_name}-${this_version}-//"|rev|cut -f 1 -d "."|rev )"
        echo "dateiendung: ${dateiendung}"
        if [ ! -z ${dateiendung} ]; then
            filepathWithArgs="${filepathWithArgs}-F \"maven2.asset${counter}.extension=${dateiendung}\" "
        fi

        #build Arguments for formula
        filepathWithArgs="${filepathWithArgs}-F \"maven2.asset${counter}=@./assets/${componentID}/${i}\" "
        mvnFilelist="${mvnFilelist},./assets/${componentID}/${i}"
        ((counter++))

    done
    #echo "debug: filepathWithArgs ${filepathWithArgs}"


    ###
    # postMvnComponent via curl -> does not work
    #if [ ! -z ${packaging} ]; then
    #    postMvnComponent ${this_group} ${this_name} ${this_version} ${packaging} unusedArg "${filepathWithArgs}"
    #else
    #    postMvnComponent ${this_group} ${this_name} ${this_version} undef unusedArg "${filepathWithArgs}"
    #fi
    #mvnGroupId=${1}
    #mvnArtifactId=${2}
    #mvnVersion=${3}
    #mvnPackaging=${4}
    #numberOfFiles=${5}  #notinuse
    #listOfFiles=${6}

    ###
    # mvnPublishFile via mvn publish
    if [ ${mvnClassifiers} = "null" ]; then
        mvnPublishFile ${this_group} ${this_name} ${this_version} ${packaging} null ${mvnFilelist} null ${mvnPomfile}
    else
        mvnPublishFile ${this_group} ${this_name} ${this_version} ${packaging} null ${mvnFiles} ${mvnClassifiers} ${mvnPomfile}
    fi

    #mvnGroupId="${1}"
    #mvnArtifactId="${2}"
    #mvnVersion="${3}"
    #mvnPackaging="${4}"
    #numberOfFiles="${5}"  #notinuse
    #listOfFiles="${6}" #komma separated
    #classifiers="${7}" #komma separated
    #pomFile="${8}"

    echo "INFO: Component ${componentID} ${this_group} ${this_name}-${this_version} migrated"




    rm -rf ./assets/${componentID}

done

cleanup()

exit 0
