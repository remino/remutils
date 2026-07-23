const dateOnlyPattern = /^(\d{4})-(\d{2})-(\d{2})$/
const dateTimePattern =
	/^(\d{4})-(\d{2})-(\d{2})[T ](\d{2}):(\d{2})(?::(\d{2})(?:\.(\d{1,3}))?)?(Z|[+-]\d{2}:\d{2})?$/

const getCurrentOffset = date => -date.getTimezoneOffset()

const formatOffset = offsetMinutes => {
	const sign = offsetMinutes >= 0 ? '+' : '-'
	const absoluteMinutes = Math.abs(offsetMinutes)
	const hours = String(Math.floor(absoluteMinutes / 60)).padStart(2, '0')
	const minutes = String(absoluteMinutes % 60).padStart(2, '0')

	return `${sign}${hours}:${minutes}`
}

export const formatLocalIso = (
	date,
	offsetMinutes = getCurrentOffset(date)
) => {
	const localDate = new Date(date.getTime() + offsetMinutes * 60_000)
	const year = localDate.getUTCFullYear()
	const month = String(localDate.getUTCMonth() + 1).padStart(2, '0')
	const day = String(localDate.getUTCDate()).padStart(2, '0')
	const hours = String(localDate.getUTCHours()).padStart(2, '0')
	const minutes = String(localDate.getUTCMinutes()).padStart(2, '0')
	const seconds = String(localDate.getUTCSeconds()).padStart(2, '0')

	return `${year}-${month}-${day}T${hours}:${minutes}:${seconds}${formatOffset(offsetMinutes)}`
}

export const parseDateInput = (value, now = new Date()) => {
	const trimmed = value.trim()
	const dateOnlyMatch = trimmed.match(dateOnlyPattern)
	const dateTimeMatch = trimmed.match(dateTimePattern)

	if (!dateOnlyMatch && !dateTimeMatch) {
		throw new Error(`invalid ISO 8601 date "${value}"`)
	}

	if (dateOnlyMatch) {
		const parsed = new Date(now)
		const offsetMinutes = getCurrentOffset(now)

		return {
			input: trimmed,
			parsed,
			fileDate: trimmed,
			frontmatterDate: formatLocalIso(parsed, offsetMinutes),
		}
	}

	const fileDate = `${dateTimeMatch[1]}-${dateTimeMatch[2]}-${dateTimeMatch[3]}`
	const hasOffset = Boolean(dateTimeMatch[8])
	const year = Number(dateTimeMatch[1])
	const month = Number(dateTimeMatch[2])
	const day = Number(dateTimeMatch[3])
	const hours = Number(dateTimeMatch[4])
	const minutes = Number(dateTimeMatch[5])
	const seconds = Number(dateTimeMatch[6] ?? '0')
	const milliseconds = Number((dateTimeMatch[7] ?? '0').padEnd(3, '0'))
	const offsetMinutes = getCurrentOffset(now)
	const parsed = hasOffset
		? new Date(trimmed)
		: new Date(
				Date.UTC(year, month - 1, day, hours, minutes, seconds, milliseconds) -
					offsetMinutes * 60_000
			)

	if (Number.isNaN(parsed.valueOf())) {
		throw new Error(`invalid ISO 8601 date "${value}"`)
	}

	return {
		input: trimmed,
		parsed,
		fileDate,
		frontmatterDate: hasOffset
			? trimmed
			: formatLocalIso(parsed, offsetMinutes),
	}
}

const pad2 = value => String(value).padStart(2, '0')

export const toLocalDateString = date =>
	`${date.getFullYear()}-${pad2(date.getMonth() + 1)}-${pad2(date.getDate())}`
