#!/bin/bash

VERMAJ="0"
VERMIN="2f"
TIMESTAMP=$(date +%c)
DEBUG="no"
DEBUGFILE="/tmp/md5image.debug"
VERBOSE="no"
FOLDERINDEX=".md5index.gz"
MODE="search"
SILENT="no"
DEPTH=""
BUILDINDEX=0
TMPCACHE="/tmp/cache.${RANDOM}"
CACHE=/tmp/md5index.cache
IGNORECACHE=no

declare -a excludes
declare -a patterns

excludes=(".git" ".compiz" ".config" ".dbus" ".gconf" ".gnome2" ".gnome2_private" ".gvfs" ".hplip" ".local" ".nano" ".salt" ".ssh", "\$RECYCLE.BIN", "System Volume Information", "Lost + Found")
patterns=()

# ShowVersion
function ShowVersion()
{
	echo -e "Version ${VERMAJ}.${VERMIN}"
}

# Usage
function Usage()
{
	echo -e "md5index Usage (${VERMAJ}.${VERMIN}) :"
	echo -e "==================="
	echo -e "General Usage\t\t\t\tmd5index [options] [cmd] [targets]"
	echo -e "-h|help\t\t\t\t\tThis messge"
	echo -e "-c|create [folder] ...\t\t\tCreate md5 index in this folder tree"
	echo -e "-u|update [folder] ...\t\t\tUpdate md5 index in this folder tree"
	echo -e "-s|search [folder] [pattern|file]...\tSearch folder tree for pattern, folder may be omitted"
	echo -e "-r|remove [folder] ...\t\t\tRemove index(es)"
	echo -e "-l [folder]\t\t\t\t\tList contents of folder index or current one"
	echo -e "-rl [folder]\t\t\t\t\tList contents of all indexs from provided folder or current one"
	echo -e "-m\t\t\t\t\tMake master index"
	echo -e "-rc\t\t\t\t\tRemove master index"
	echo -e "-e [file]\t\t\t\tItems to exclude are in file"
	echo -e "-ex|expr [file]\t\t\t\tItems to search for are in file"
	echo -e "-debug\t\t\t\t\tTurn debug mode on"
	echo -e "-n\t\t\t\t\tNo prompt mode"
	echo -e "shell [folder]\t\t\t\tExecute interactive index shell"
}

# ShellUsage :
# Usage : ShellUsage
function ShellUsage()
{
	echo -e "Shell Usage (${VERMAJ}.${VERMIN})"
	echo -e "================"
	echo -e "create [folder]\t\t\tCreate Index in supplied folder, if not supplied, current folder"
	echo -e "update [folder]\t\t\tUpdate Index in supplied folder, if not supplied, current folder"
	echo -e "remove [folder]\t\t\tRemove Indexes from supplied folder tree, if not supplied, current folder"
	echo -e "search [folder] [pattern]\tSearch Indexes for pattern, if folder is not supplied, assume current folder"
	echo -e "cache [folder]\t\t\tBuild a cache from the indexes in the folder structure for faster searching"
	echo -e "removecache\t\t\tRemove master index cache"
	echo -e "list [folder]\t\t\tList contents of index of supplied or current folder"
	echo -e "rlist [folder]\t\t\tList contents of index of supplied or current folder"
	echo -e "rmi [file]\t\t\tRemove file, and update index"
	echo -e "mvi [file] [dest]\t\tMove file, update source and destination indexes, if either folder has no index, no index is created or updated"
	echo -e "cpi [file] [dest]\t\tCopy file to destination and update index, if there is no index, one will not be created"
	echo -e "help\t\t\t\tThis message"
	echo -e "quit|exit\t\t\tExit shell"
}

# DebugMsg
# Usage : DebugMsg [message]
function DebugMsg()
{
	TIMESTAMP=$(date +%c)

	if [ "${1}" = "yes" ]; then
		shift 1
		message="${TIMESTAMP} : ${*}"
	elif [ "${1}" = "no" ]; then
		shift 1
		message="${*}"
	else
		message="${TIMESTAMP} : ${*}"
	fi

	if [ "${DEBUG}" = "y" -o "${DEBUG}" = "yes" ]; then
		[ "${SILENT}" = "no" ] && echo -en "${message}"
		echo -en "${message}" >> "${DEBUGFILE}"
	fi
}

# DebugMsgLine
# Usage : DebugMsgLine [message]
function DebugMsgLine()
{
	TIMESTAMP=$(date +%c)

	if [ "${1}" = "yes" ]; then
		shift 1
		message="${TIMESTAMP} : ${*}"
	elif [ "${1}" = "no" ]; then
		shift 1
		message="${*}"
	else
		message="${TIMESTAMP} : ${*}"
	fi

	if [ "${DEBUG}" = "y" -o "${DEBUG}" = "yes" ]; then
		[ "${SILENT}" = "no" ] && echo -e "${message}"
		echo -e "${message}" >> "${DEBUGFILE}"
	fi
}

# Load Search Expressions
# Usage : LoadExpressions {file}
function LoadExpressions()
{
	mapfile -t -O ${#patterns[@]} patterns < "${1}"
}

# Load Excludes
# Usage : LoadExcludes {exclude file}
function LoadExcludes()
{
	mapfile -t -O ${#excludes[@]} excludes < "${1}"
}

# Check Exclude List
# Usage : Excluded {item}
function Excluded()
{
	if [ ! "${1}" = "" ]; then
		for ((index=0; index < ${#excludes[@]}; ++index)); do
			abspath=$(realpath "${1}")
			target=$(basename "${abspath}")

			[ "${excludes[${index}]}" = "${target}" ] && return 1
		done
	fi

	return 0
}

# FindIndexes : Find All Indexes in a given folder tree
# Usage : FindIndexes {folder1} {folder2}
function FindIndexes()
{
	while [ ! "${1}" = "" ]; do
		abspath=$(realpath "${1}")

		pushd "${abspath}" > /dev/null

		mapfile -t indexes < <(find . ${DEPTH} -name "${FOLDERINDEX}" -type f)

		for ((index=0; index < ${#indexes[@]}; ++index)); do
			abspath=$(realpath "${indexes[${index}]}")

			echo -e "${abspath}"
		done

		popd > /dev/null

		shift 1
	done
}

# RemoveIndexes : Remove All Indexes
# Usage : RemoveIndexes {folder} ...
function RemoveIndexes()
{
	while [ ! "${1}" = "" ]; do
		pushd "${1}" > /dev/null

		mapfile -t indexes < <(find . ${DEPTH} -name "${FOLDERINDEX}" -type f)

		for ((index=0; index < ${#indexes[@]}; ++index)); do
			item="${indexes[${index}]}"

			flag="n"

			if [ "${SILENT}" = "no" ]; then
				read -p "Delete ${item} (y/n)? " flag
			else
				flag="y"
			fi

			[ "${flag}" = "y" ] && rm "${item}"
		done

		popd > /dev/null

		shift 1
	done
}

# Marked
# MkTempIndex : Make Temporary Index file
# Usage : MkTempIndex {folder} {tmpfile}
function MkTempIndex()
{
	pushd "${1}" > /dev/null

	gzip -dc "${FOLDERINDEX}" > "${2}"

	popd > /dev/null
}

# Marked
# AddToFolderTmpIndex
# Usage : AddToFolderTmpIndex {file to add} {newindextmpfile}
function AddToFolderTmpIndex()
{
	Excluded "${1}"

	if [ $? -eq 0 ]; then
		md5sum "${1}" >> "${2}"
	fi
}

# Mkmd5Index : Make md5 Index inside the current folder
# Usage : Mkmd5Index
function MkMD5Index()
{
	local -a files
	local -a sums

	mapfile -t files < <(ls -1)

	for ((fileIndex=0; fileIndex < ${#files[@]}; ++fileIndex)); do
		fop="${files[${fileIndex}]}"

		if [ -f "${fop}" ]; then
			DebugMsgLine "Hashing : ${fop}"
			sums[${#sums[@]}]=$(md5sum "${fop}")
		fi
	done

	if [ ${#sums[@]} -gt 0 ]; then
		SKIPME=0
		DebugMsgLine "Creating/Replacing ${FOLDERINDEX}"
		if [ -e "${FOLDERINDEX}" ]; then
			if [ -w "${FOLDERINDEX}" ]; then
				rm "${FOLDERINDEX}"
			else
				echo -e "${FOLDERINDEX} exists and is not removable"
				SKIPME=1
			fi
		else
			TMP=${RANDOM}

			touch ${TMP} > /dev/null 2>&1

			if [ ! $? -eq 0 ]; then
				echo -e "${FOLDERINDEX} is not writable"
				SKIPME=1
			else
				rm ${TMP}
			fi
		fi

		if [ ${SKIPME} -eq 0 ]; then
			for ((sumIndex=0; sumIndex < ${#sums[@]}; ++sumIndex)); do
				echo "${sums[${sumIndex}]}"
			done | gzip -c > "${FOLDERINDEX}"
		fi
	fi
}

# MakeFolderIndexes : Make Folder Index
# Usage : MakeFolderIndexes {folder} ...
function MakeFolderIndexes()
{
	local -a items

	while [ ! "${1}" = "" ]; do
		if [ -d "${1}" ]; then
			ABSPATH=$(realpath "${1}")

			echo "${ABSPATH}"

			mapfile -t items < <(find "${ABSPATH}" ${DEPTH} -type d)

			for ((folderIndex=0; folderIndex < ${#items[@]}; ++folderIndex)); do
				folder="${items[${folderIndex}]}"

				DebugMsgLine "Processing : ${folder} - ${folderIndex}"

				pushd "${folder}" > /dev/null

				MkMD5Index

				popd > /dev/null
			done
		fi

		shift 1
	done
}

# AddToFolderIndex
# Usage : AddToFolderIndex {file} {folder-optional}
function AddToFolderIndex()
{
	TMPINDEX="/tmp/tmpindex.${RANDOM}"

	[ ! "${2}" = "" ] && pushd "${2}" > /dev/null

	if [ -e "${1}" ]; then
		if [ -e "${FOLDERINDEX}" ]; then
			zcat "${FOLDERINDEX}" > "${TMPINDEX}"
		fi

		AddToFolderTmpIndex "${1}" "${TMPINDEX}"

		rm "${FOLDERINDEX}"
		gzip -c "${TMPINDEX}" > "${FOLDERINDEX}"
	else
		echo -e "File not found"
	fi

	[ -e "${TMPINDEX}" ] && rm "${TMPINDEX}"

	[ ! "${2}" = "" ] && popd > /dev/null
}

# UpdateFolderIndex : Update Folder Index
# Usage : UpdateFolderIndex {folder} ...
function UpdateFolderIndex()
{
	while [ ! "${1}" = "" ]; do
		if [ -d "${1}" ]; then
			mapfile -t folders < <(find "${1}" ${DEPTH} -type d)

			for ((index=0; index < ${#folders[@]}; ++index)); do
				folder="${folders[${index}]}"

				DebugMsgLine "Processing : ${folder}"
				pushd "${folder}" > /dev/null

				if [ -f "${FOLDERINDEX}" ]; then
					TMPINDEX="/tmp/index.tmp.${RANDOM}"
					TMPNEWINDEX="${TMPINDEX}.new"

					zcat "${FOLDERINDEX}" > "${TMPINDEX}"
					mapfile -t listing < <(ls -1)

					touch "${TMPNEWINDEX}"

					while read chksum file; do
						if [ -e "${file}" ]; then
							echo "${chksum} ${file}" >> "${TMPNEWINDEX}"
						fi
					done < "${TMPINDEX}"

					for ((findex=0; findex < ${#listing[@]}; ++findex)); do
						file="${listing[${findex}]}"

						if [ -f "${file}" ]; then
							grep -F "${file}" "${TMPNEWINDEX}" > /dev/null

							if [ $? -ne 0 ]; then
								DebugMsgLine "Checksumming : ${file}"
								md5sum "${file}" >> ${TMPNEWINDEX}
							fi
						fi
					done

					# Test for changed
					DebugMsg yes "Testing for changes in index : "
					orig=$(md5sum "${TMPINDEX}" | cut -d" " -f1)
					newin=$(md5sum "${TMPNEWINDEX}" | cut -d" " -f1)

					if [ -s "${TMPNEWINDEX}" -a ! ${orig} = ${newin} ]; then
						DebugMsgLine no "And there are changes"
						[ -e "${FOLDERINDEX}" ] && rm "${FOLDERINDEX}"
						cat "${TMPNEWINDEX}" | gzip > "${FOLDERINDEX}"
					else
						DebugMsgLine no "And there were NO changes"
						touch "${FOLDERINDEX}"
					fi

					[ -e "${TMPINDEX}" ] && rm "${TMPINDEX}"
					[ -e "${TMPNEWINDEX}" ] && rm "${TMPNEWINDEX}"
				else
					MkMD5Index .
				fi

				popd > /dev/null
			done
		fi

		shift 1
	done
}

# ListIndex : List contents of index
# Usage : ListIndex {r|s} {folder}
function ListIndex()
{
	if [ "$2" = "" ]; then
		folder="."
	else
		folder="$2"
	fi


}

# SearchFolderIndexes : Search folder indexes for patterns
# Usage : SearchFolderIndexes {folder} {pattern} ...
function SearchFolderIndexes()
{
	PATTERNFILE="/tmp/patterns.${RANDOM}"
	TMPGREP="/tmp/grep.${RANDOM}"

	local -a targets

	for ((count=0; count < ${#patterns[@]}; ++count)); do
		pattern="${patterns[${count}]}"
		if [ -f "${pattern}" ]; then
			cat "${pattern}" >> "${PATTERNFILE}"
		else
			echo "${pattern}" >> "${PATTERNFILE}"
		fi
	done

	while [ ! "${1}" = "" ]; do
		if [ -d "${1}" ]; then
			targets[${#targets[@]}]="${1}"
		elif [ -f "${1}" ]; then
			# Add both name and MD5SUM so we can possibly locate either
			sum=$(md5sum "${1}")
			echo "${sum}" >> "${PATTERNFILE}"
			echo "${1}" >> "${PATTERNFILE}"
		else
			echo "${1}" >> "${PATTERNFILE}"
		fi

		shift 1
	done

	[ ${#targets[@]} -eq 0 ] && targets[0]="."

	foundany=1

	for ((index=0; index < ${#targets[@]}; ++index)); do
		pushd "${targets[${index}]}" > /dev/null

		mapfile -t < <(find . ${DEPTH} -name "${FOLDERINDEX}")

		count=${#MAPFILE[@]}

		for ((item=0; item < ${count}; ++item)); do
			findex="${MAPFILE[${item}]}"
			pfolder=$(dirname "${findex}")
			folder=$(realpath "${pfolder}")

			if [ -e "${CACHE}" -a -s "${PATTERNFILE}" ]; then
				egrep -f "${PATTERNFILE}" "${CACHE}" > "${TMPGREP}"
			elif [ -s "${PATTERNFILE}" ]; then
				zcat "${findex}" | egrep -f "${PATTERNFILE}" > "${TMPGREP}"
			else
				zcat "${findex}" > "${TMPGREP}"
			fi

			if [ -s ${TMPGREP} ]; then
				foundany=0
				while read chksum file; do
					if [ -e "${CACHE}" ]; then
						printf "%s %s \t(from ${CACHE})\n" "${chksum}" "${file}"
					else
						printf "%s %s/%s\n" "${chksum}" "${folder}" "${file}"
					fi
				done < "${TMPGREP}"

				[ -e "${CACHE}" ] && break
			fi
		done

		popd > /dev/null

		[ -e "${TMPGREP}" ] && rm "${TMPGREP}"
		[ -e "${PATTERNFILE}" ] && rm "${PATTERNFILE}"
	done

	return ${foundany}
}

# MakeMasterIndex : Make master index of all indexes in a folder tree
# Usage : MakeMasterIndex [root folder] [master index fname]
function MakeMasterIndex()
{
	DebugMsgLine "Entering MakeMasterIndex"

	if [ ! "${1}" = "" ]; then
		declare -a indexes

		DebugMsgLine "Commencing build of master index"

		masterindex="${CACHE}"
		tmpindex="/tmp/index.tmp.${RANDOM}"

		pushd "${1}" > /dev/null
		mapfile -t indexes < <(find . -name "${FOLDERINDEX}")

		for ((item=0; item < ${#indexes[@]}; ++item)); do
			md5index=$(realpath "${indexes[${item}]}")

			zcat "${md5index}" > "${tmpindex}"
			parent=$(dirname "${md5index}")

			while read chksum file; do
				echo -e "${chksum} ${parent}/${file}" >> "${masterindex}"
			done < "${tmpindex}"
		done

		[ -e "${tmpindex}" ] && rm "${tmpindex}"

		popd > /dev/null
	fi

	DebugMsgLine "Leaving MakeMasterIndex"
}

# Duplicates
# Usages : Duplicates [folder1]  ...
function Duplicates()
{
	declare -a duplist
	declare -a duptmplist
	declare -a matches

	DebugMsgLine "Function Duplicates"

	tmpdups="/tmp/tempdups.${RANDOM}"

	# If one folder, the user has selected to find any duplicates in that one folder tree
	# So, we trick the code by making 2 items in list, both of which happen to be the same folder.
	while [ ! "${1}" = "" ]; do
		duplist[${#duplist[@]}]="${1}"
		duptmplist[${#duptmplist[@]}]="/tmp/dup.${RANDOM}"
		shift 1
	done

	# If the list is empty... there is no point in continuing.
	if [ ${#duplist[@]} -gt 0 ]; then
		if [ ${#duplist[@]} -eq 1 ]; then
			duplist[1]="${duplist[0]}"
			duptmplist[1]="/tmp/dup.${RANDOM}"
		fi

		# Search for dups...
		# This assumes we are looking for dups in every folder but the first.

		primaryindex="${duptmplist[0]}"
		MakeMasterIndex "${duplist[0]}" "${primaryindex}"

		for ((index=1; index < ${#duplist[@]}; ++index)); do
			currentindex="${duptmplist[${index}]}"
			MakeMasterIndex "${duplist[${index}]}" "${currentindex}"

			while read chksum file; do
				matched=false
				if [ ${#matches[@]} -gt 0 ]; then
					for ((match=0; match < ${#matches[@]}; ++match)); do
						if [ "${file}" = "${matches[${match}]}" ]; then
							matched=true
							break
						fi
					done
				fi

				if [ ${matched} = false ]; then
					grep -F "${chksum}" "${primaryindex}" | grep -v -F "${chksum} ${file}" > "${tmpdups}"

					while read chksm fname; do
						printf "%s,%s,%s\n" "${chksum}" "${fname}" "${file}"
						matches[${#matches[@]}]="${fname}"
					done < "${tmpdups}"
				fi
			done < "${currentindex}"

			[ -e "${duptmplist[${index}]}" ] && rm "${duptmplist[${index}]}"
		done

		[ -e "${tmpdups}" ] && rm "${tmpdups}"
		[ -e "${primaryindex}" ] && rm "${primaryindex}"
	fi
}

# RemoveFromIndex :
# Usage : RemoveFromIndex [src] ...
function RemoveFromIndex()
{
	for item in $*; do
		abspath=$(realpath "${item}")
		parent=$(dirname "${abspath}")
		filename=$(basename "${abspath}")

		pushd "${parent}" > /dev/null

		rm "${filename}"

		if [ -e ${FOLDERINDEX} ]; then
			UpdateFolderIndex .
		fi

		popd > /dev/null
	done
}

# MoveFromFolder :
# Usage : MoveFromFolder [src] [dest]
function MoveFromFolder()
{
	abspaths=$(realpath "${1}")
	parents=$(dirname "${abspaths}")
	filenames=$(basename "${abspaths}")

	abspathd=$(realpath "${2}")
	parentd=$(dirname "${abspathd}")

	mv "${abspaths}" "${abspathd}"

	UpdateIndexes "${abspaths}"
	UpdateIndexes "${abspathd}"
}

# CopyToFolder :
# Usage : CopyToFolder [src] [dest]
function CopyToFolder()
{
	abspaths=$(realpath "${1}")
	parents=$(dirname "${abspaths}")
	filenames=$(basename "${abspaths}")

	abspathd=$(realpath "${2}")
	parentd=$(dirname "${abspathd}")

	cp "${abspaths}" "${abspathd}"

	UpdateIndexes "${abspaths}"
	UpdateIndexes "${abspathd}"
}

# Interactive Index Shell
function InteractiveShell()
{
	SHPROMPT="$(pwd)> "

	while read -p "${SHPROMPT}" cmd first second remainder; do
        	case "${cmd}" in
		"usage"|"help")	ShellUsage ;;
		"create")	if [ "${first}" = "" ]; then
					MakeFolderIndexes .
				else
					eval MakeFolderIndexes ${first} ${second} ${remainder}
				fi
				;;
        	"search")	if [ "${second}" = "" -a "${remainder}" = "" ]; then
					eval SearchFolderIndexes . "${first}"
				else
					eval SearchFolderIndexes ${first} ${second} ${remainder}
				fi
				;;
		"update")	if [ "${first}" = "" ]; then
					UpdateFolderIndex .
				else
					eval UpdateFolderIndex ${first} ${second} ${remainder}
				fi
				;;
		"remove")	if [ "${first}" = "" ]; then
					RemoveIndexes .
				else
					eval RemoveIndexes ${first} ${second} ${remainder}
				fi
				;;
		"cache")	if [ "${first}" = "" ]; then
					MakeMasterIndex .
				else
					eval MakeMasterIndex ${first} ${second} ${remainder}
				fi
				;;
		"removecache")	[ -e "${CACHE}" ] && rm "${CACHE}" ;;
		"rmi")		RemoveFromIndex ${first} ${second} ${remainder} ;;
		"mvi")		MoveFromFolder ${first} ${second} ${remainder} ;;
		"cpi")		CopyToFolder ${first} ${second} ${remainder} ;;
		"duplicates")	Duplicates "${first}" "${second}" ${remainder} ;;
        	"quit"|"exit")
                	break ;;
        	*)
                	eval ${cmd} ${first} ${second} ${remainder} ;;
        	esac

        	SHPROMPT="$(pwd)> "
	done
}

# TestFunc : Test a function in script
# Usage : TestFunc [function to test] [any parameters]
function TestFunc()
{
	eval ${*}
}

#
# Main Loop
#

if [ ${DEBUG} = "yes" ]; then
	touch ${DEBUGFILE}
	echo "md5index called on ${TIMESTAMP}"
else
	[ -e ${DEBUGFILE} ] && rm ${DEBUGFILE}
fi

declare -a cmds

while [ ! "${1}" = "" ]; do
	case "${1}" in
	"-h"|"help")	MODE="${1}"; break ;;
	"-c"|"create")	MODE="${1}"; break ;;
	"-u"|"update")	MODE="${1}"; break ;;
	"-s"|"search")	MODE="${1}"; break ;;
	"-r"|"remove")	MODE="${1}"; break ;;
	"-sh"|"shell")	MODE="${1}"; break ;;
	"-f"|"find")	MODE="${1}"; break ;;
	"-v"|"version")	MODE="${1}"; break ;;
	"duplicates")	MODE="${1}"; break ;;
	"test")		MODE="${1}"; break ;;
	"-m"|"cache")	MODE="${1}"; break ;;
	"-rc"|"removecache")
			MODE="${1}"; break ;;
	"-d"|"depth")
		DEPTH="-maxdepth ${2}"; shift 1 ;;
	"-n")	SILENT="yes" ;;
	"-e"|"exclude")
		LoadExcludes "${2}"; shift 1 ;;
	"-ex"|"expressions"|"expr")
		LoadExpressions "${2}"; shift 1 ;;
	"-debug")
		DEBUG="yes" ;;
	esac

	shift 1
done

DebugMsgLine "Finished processing Cmdline Args"

shift 1

itemsfound=1

DebugMsgLine "Starting to process ${MODE}"

case "${MODE}" in
"-h"|"help")	Usage; exit 127 ;;
"-c"|"create")	MakeFolderIndexes $* ;;
"-u"|"update")	UpdateFolderIndex $* ;;
"-s"|"search")	if [ "${*}" = "" ]; then
			SearchFolderIndexes .
			itemsfound=$?
		else
			SearchFolderIndexes $*
			itemsfound=$?
		fi ;;
"-r"|"remove")	RemoveIndexes $* ;;
"test")		TestFunc $* ;;
"duplicates")	Duplicates $* ;;
"-f"|"find")	FindIndexes $* ;;
"-v"|"version")	ShowVersion ;;
"-m"|"cache")	MakeMasterIndex $* ;;
"-rc"|"removecache")
		[ -e "${CACHE}" ] && rm "${CACHE}" ;;
"-sh"|"shell")	InteractiveShell $* ;;
esac

[ "${MODE}" = "-s" -o "${MODE}" = "search" ] && exit ${itemsfound}
