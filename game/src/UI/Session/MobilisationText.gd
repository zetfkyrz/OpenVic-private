extends RefCounted
## The texts of the mobilisation (docs/RECRUITMENT.md, "Мобилизация") for the top bar and the military screen: the pool of the poor pops, the days
## of the gathering, the penalty of the economy, the state of a mobilised country. The data is PlayerSingleton.get_mobilisation().


static func thousands(value: int) -> String:
	var text: String = str(absi(value))
	var grouped: String = ""
	while text.length() > 3:
		grouped = " " + text.substr(text.length() - 3) + grouped
		text = text.substr(0, text.length() - 3)
	return ("-" if value < 0 else "") + text + grouped


## The share of the output the economy loses, in percent (0.93 -> "7")
static func penalty_pct(output_multiplier: float) -> String:
	return str(roundi((1.0 - output_multiplier) * 1000.0) / 10.0)


static func tooltip(mobilisation: Dictionary) -> String:
	if mobilisation.is_empty():
		return ""
	var lines: PackedStringArray = []
	if bool(mobilisation[&"is_mobilised"]):
		lines.append("§RСтрана мобилизована§W")
		lines.append("Мобилизованные полки: %d (%s чел., по штату %s)" % [int(mobilisation[&"regiments"]),
			thousands(int(mobilisation[&"men"])), thousands(int(mobilisation[&"full_men"]))])
		var pending: int = int(mobilisation[&"pending_regiments"])
		if pending > 0:
			lines.append("Собираются ещё %d полков: до %d дн." % [pending, int(mobilisation[&"days_left"])])
		lines.append("Экономика: выпуск РГО и заводов −%s %% — люди в армии, а не на работе" % penalty_pct(float(mobilisation[&"output_multiplier"])))
		lines.append("Пополнение — из пула мобилизации: свободно %s чел." % thousands(maxi(0, int(mobilisation[&"free_men"]))))
		var wanted: int = int(mobilisation[&"reinforce_wanted_men"])
		if wanted > 0:
			lines.append("Пополнение вчера: %s из %s чел." % [thousands(int(mobilisation[&"reinforce_given_men"])), thousands(wanted)])
		if bool(mobilisation[&"war_seen"]) and not bool(mobilisation[&"at_war"]):
			lines.append("Война окончена: демобилизация сама через %d дн." % maxi(0,
				int(mobilisation[&"demobilise_days"]) - int(mobilisation[&"peace_days"])))
		elif not bool(mobilisation[&"war_seen"]):
			lines.append("Демобилизация — вручную; после войны она пройдёт сама через %d дн." % int(mobilisation[&"demobilise_days"]))
		var demobilise_reason: String = mobilisation[&"demobilise_reason"]
		if demobilise_reason.is_empty():
			lines.append("Демобилизация распускает мобилизованные полки: люди возвращаются домой, никто не гибнет.")
		else:
			lines.append("§RДемобилизоваться нельзя: %s§W" % demobilise_reason)
	else:
		lines.append("Мобилизация: %d полков (%s чел.)" % [int(mobilisation[&"pool_regiments"]), thousands(int(mobilisation[&"pool_men"]))])
		lines.append("  из бедного населения своих провинций (крестьяне, рабочие, ремесленники): %s чел. × %s %%" % [
			thousands(int(mobilisation[&"pop_men"])), str(roundi(float(mobilisation[&"share"]) * 1000.0) / 10.0)])
		lines.append("  на ненациональной земле (не ядра страны) в 100 раз меньше; с региона — не больше 25 % его населения (ненационального — 0.25 %)")
		var days_min: int = int(mobilisation[&"days_min"])
		var days_max: int = int(mobilisation[&"days_max"])
		if days_max > 0:
			lines.append("Сбор: %s дн. (быстрее там, где есть железные дороги)" % (str(days_min) if days_min == days_max else "%d–%d" % [days_min, days_max]))
		lines.append("Штраф экономики: выпуск РГО и заводов −%s %%, пока люди в армии" % penalty_pct(float(mobilisation[&"planned_output_multiplier"])))
		lines.append("Товары для сбора не нужны; снабжение — как у всех полков.")
		lines.append("Мобилизованные не входят в людские ресурсы солдат: не дают превышения, пополняются из своего пула.")
		var mobilise_reason: String = mobilisation[&"mobilise_reason"]
		if not mobilise_reason.is_empty():
			lines.append("§RМобилизоваться нельзя: %s§W" % mobilise_reason)
	return "\n".join(lines)
