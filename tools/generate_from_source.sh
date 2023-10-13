set -e

TMPDIR="/tmp"

CODENAF="96.02A" # Coiffeurs
DBNAME='coiffeurs.sqlite'
TABLENAME="Coiffeurs"

#CODENAF="47.22" # Bouchers
#TABLENAME="Bouchers"
#DBNAME='bouchers.sqlite'


echo "On travaille dans ${TMPDIR}"

SEZIP="${TMPDIR}/StockEtablissement_utf8.zip"
SULZIP="${TMPDIR}/StockUniteLegale_utf8.zip"

SECSV="${TMPDIR}/StockEtablissement_utf8.csv"
SULCSV="${TMPDIR}/StockUniteLegale_utf8.csv"

SECSV_OUT="${TMPDIR}/BSE.csv"
SULCSV_OUT="${TMPDIR}/BSUL.csv"

NEWDB="${TMPDIR}/${DBNAME}"
OLDDB="${DBNAME}"

OLDDB_BACKUP="old/${OLDDB}-$(date +%Y%m%d)"
if [ ! -f ${OLDDB_BACKUP} ]; then
    if [ -f ${OLDDB} ]; then
      cp "${OLDDB}" "old/${OLDDB}-$(date +%Y%m%d)"
    fi
fi

SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )

if [[ ! -f "${SEZIP}" ]]; then
    wget "https://files.data.gouv.fr/insee-sirene/$(basename ${SEZIP})" -O "${SEZIP}"
fi
if [[ ! -f "${SULZIP}" ]]; then
    wget "https://files.data.gouv.fr/insee-sirene/$(basename ${SULZIP})" -O "${SULZIP}"
fi

echo "De-zip des fichiers si nécessaire"
if [[ ! -f "${SECSV}" ]]; then
    unzip "${SEZIP}" -d "${TMPDIR}"
fi
if [[ ! -f "${SULCSV}" ]]; then
    unzip "${SULZIP}" -d "${TMPDIR}"
fi

if [[ ! -f "${SECSV_OUT}" ]]; then
    echo "Extraction des lignes intéressantes du fichiers ${SECSV}"
    { head -n 1 "${SECSV}"  & grep "${CODENAF}" "${SECSV}" ; } > "${SECSV_OUT}"
else
    echo "Fichier ${SECSV_OUT} déjà présent..."
fi
if [[ ! -f "${SULCSV_OUT}" ]]; then
    echo "Extraction des lignes intéressantes du fichiers ${SULCSV}"
    { head -n 1 "${SULCSV}"  & grep "${CODENAF}" "${SULCSV}" ; } > "${SULCSV_OUT}"
else
    echo "Fichier ${SULCSV_OUT} déjà présent..."
fi

if [[ ! -f "${NEWDB}" ]]; then
    echo "Création de la nouvelle base de données ${NEWDB}"
    ruby "${SCRIPT_DIR}/sirene.rb" "${SECSV_OUT}" "${SULCSV_OUT}" "${NEWDB}" "${CODENAF}" "${TABLENAME}"
else
    echo "Base de données ${NEWDB} déjà présente..."
fi

if [[ -f "${OLDDB}" ]]; then
    ruby "${SCRIPT_DIR}/compare.rb" "${OLDDB}" "${NEWDB}"
else
    ruby "${SCRIPT_DIR}/blague.rb" --db="${NEWDB}" --bad=bad --good=good --table="${TABLENAME}"
    echo "Ancienne base de données ${OLDDB} non présente... exit"
fi
echo Running ruby "${SCRIPT_DIR}/coords.rb" "${OLDDB}"
ruby "${SCRIPT_DIR}/coords.rb" "${OLDDB}"
echo Running ruby "${SCRIPT_DIR}/anomalies.rb" "${OLDDB}"
ruby "${SCRIPT_DIR}/anomalies.rb" "${OLDDB}"
echo Running ruby "${SCRIPT_DIR}/main.rb" "${OLDDB}"
ruby "${SCRIPT_DIR}/main.rb" "${OLDDB}"

echo "Fini!"
echo "Le nouveau fichier sqlite est ${NEWDB}"
