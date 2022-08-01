set -e

TMPDIR="/tmp"

echo "On travaille dans ${TMPDIR}"

SEZIP="${TMPDIR}/StockEtablissement_utf8.zip"
SULZIP="${TMPDIR}/StockUniteLegale_utf8.zip"

SECSV="${TMPDIR}/StockEtablissement_utf8.csv"
SULCSV="${TMPDIR}/StockUniteLegale_utf8.csv"

SECSV_OUT="${TMPDIR}/BSE.csv"
SULCSV_OUT="${TMPDIR}/BSUL.csv"

NEWDB="${TMPDIR}/coiffeurs.sqlite"

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
    { head -n 1 "${SECSV}"  & grep "96.02A" "${SECSV}" ; } > "${SECSV_OUT}"
else
    echo "Fichier ${SECSV_OUT} déjà présent..."
fi
if [[ ! -f "${SULCSV_OUT}" ]]; then
    echo "Extraction des lignes intéressantes du fichiers ${SULCSV}"
    { head -n 1 "${SULCSV}"  & grep "96.02A" "${SULCSV}" ; } > "${SULCSV_OUT}"
else
    echo "Fichier ${SULCSV_OUT} déjà présent..."
fi

if [[ ! -f "${NEWDB}" ]]; then
    echo "Création de la nouvelle base de données ${NEWDB}"
    ruby "${SCRIPT_DIR}/sirene.rb" "${SECSV_OUT}" "${SULCSV_OUT}" "${NEWDB}"
else
    echo "Base de données ${NEWDB} déjà présente..."
fi

echo "Fini!"
echo "Le nouveau fichier sqlite est ${NEWDB}"
echo "Si vous mettez à jour par rapport à un fichier précédent, lancez:"
echo "ruby ${SCRIPT_DIR}/compare.rb <fichier_sqlite_actuel> ${NEWDB}"
