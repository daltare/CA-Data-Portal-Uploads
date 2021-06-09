import csv, os

def selectByAnalyte(path, fileName, analytes, newFileName, field_filter):
	file = os.path.join(path, fileName)
	fileOut = os.path.join(path, newFileName)
	columns = []
	with open(file, 'r', newline='', encoding='utf8') as txtfile:
		reader = csv.reader(txtfile, delimiter='\t', lineterminator='\n')
		with open(fileOut, 'w', newline='', encoding='utf8') as txtfileOut:
			writer = csv.writer(txtfileOut, csv.QUOTE_NONE, delimiter='\t', lineterminator='\n')
			count = 0
			for row in reader:
				if count == 0:
					columns = row
					writer.writerow(row)
					count += 1
					continue
				rowDict = dict(zip(columns, row))
				if rowDict[field_filter] in analytes:
					writer.writerow(row)

##############################################################################
########################## Main Statement  ###################################
##############################################################################

# Necessary variables imported from user's environmental variables.
if __name__ == "__main__":
	#analytes = ['E. Coli', 'Enterococcus', 'Coliform, Total', 'Coliform, Fecal', ]
	analytes = ["Acetamiprid", "Acibenzolar-S-methyl", "Aldicarb", "Aldicarb ", "Aldicarb Sulfone", "Aldicarb Sulfoxide", "Aldrin", "Aldrin, Particulate", "Allethrin", "Ametryn", "Aminocarb", "AMPA", "Anilazine", "Aspon", "Atraton", "Atrazine", "Azinphos Ethyl", "Azinphos Methyl", "Azoxystrobin", "Barban", "Bendiocarb", "Benfluralin", "Benomyl", "Bensulfuron Methyl", "Bentazon", "Bifenox", "Bifenthrin", "Bispyribac Sodium", "Bolstar", "Bromacil", "Captafol", "Captan", "Carbaryl", "Carbendazim", "Carbofuran", "Carbophenothion", "Carfentrazone Ethyl", "Chlorantraniliprole", "Chlordane", "Chlordane, cis-", "Chlordane, cis-, Particulate", "Chlordane, Technical", "Chlordane, trans-", "Chlordane, trans-, Particulate", "Chlordene, cis-", "Chlordene, trans-", "Chlorfenapyr", "Chlorfenvinphos", "Chlorobenzilate", "Chlorothalonil", "Chlorpropham", "Chlorpyrifos", "Chlorpyrifos Methyl", "Chlorpyrifos Methyl, Particulate", "Chlorpyrifos Methyl/Fenchlorphos", "Chlorpyrifos, Particulate", "Cinerin-2", "Ciodrin", "Clomazone", "Clothianidin", "Coumaphos", "Cyanazine", "Cyantraniliprole", "Cycloate", "Cyfluthrin", "Cyfluthrin, beta-", "Cyfluthrin-1", "Cyfluthrin-2", "Cyfluthrin-3", "Cyfluthrin-4", "Cyhalofop-butyl", "Cyhalothrin", "Cyhalothrin lambda-", "Cyhalothrin, gamma-", "Cyhalothrin, lambda-1", "Cyhalothrin, lambda-2", "Cypermethrin", "Cypermethrin-1", "Cypermethrin-2", "Cypermethrin-3", "Cypermethrin-4", "Cyprodinil", "Dacthal", "Dacthal, Particulate", "DCBP(p,p')", "DDD(o,p')", "DDD(o,p'), Particulate", "DDD(p,p')", "DDD(p,p'), Particulate", "DDE(o,p')", "DDE(o,p'), Particulate", "DDE(p,p')", "DDE(p,p'), Particulate", "DDMU(p,p')", "DDMU(p,p'), Particulate", "DDT(o,p')", "DDT(o,p'), Particulate", "DDT(p,p')", "DDT(p,p'), Particulate", "Deltamethrin", "Deltamethrin/Tralomethrin", "Demeton", "Demeton-O", "Demeton-s", "Desethyl-Atrazine", "Desisopropyl-Atrazine", "Diazinon", "Diazinon, Particulate", "Dichlofenthion", "Dichlone", "Dichloroaniline, 3,5-", "Dichlorobenzenamine, 3,4-", "Dichlorophenyl Urea, 3,4-", "Dichlorophenyl-3-methyl Urea, 3,4-", "Dichlorvos", "Dichrotophos", "Dicofol", "Dicrotophos", "Dieldrin", "Dieldrin, Particulate", "Diflubenzuron", "Dimethoate", "Dioxathion", "Diphenamid", "Diphenylamine", "Diquat", "Disulfoton", "Dithiopyr", "Diuron", "Endosulfan I", "Endosulfan I, Particulate", "Endosulfan II", "Endosulfan II, Particulate", "Endosulfan Sulfate", "Endosulfan Sulfate, Particulate", "Endrin", "Endrin Aldehyde", "Endrin Ketone", "Endrin, Particulate", "EPN", "EPTC", "Esfenvalerate", "Esfenvalerate/Fenvalerate", "Esfenvalerate/Fenvalerate-1", "Esfenvalerate/Fenvalerate-2", "Ethafluralin", "Ethion", "Ethoprop", "Famphur", "Fenamiphos", "Fenchlorphos", "Fenhexamid", "Fenitrothion", "Fenpropathrin", "Fensulfothion", "Fenthion", "Fenuron", "Fenvalerate", "Fipronil", "Fipronil Amide", "Fipronil Desulfinyl", "Fipronil Desulfinyl Amide", "Fipronil Sulfide", "Fipronil Sulfone", "Flonicamid", "Fluometuron", "Fluridone", "Flusilazole", "Fluvalinate", "Fluxapyroxad", "Folpet", "Fonofos", "Glyphosate", "Halosulfuron Methyl", "HCH, alpha-", "HCH, alpha-, Particulate", "HCH, beta-", "HCH, beta-, Particulate", "HCH, delta-", "HCH, delta-, Particulate", "HCH, gamma-", "HCH, gamma-, Particulate", "Heptachlor", "Heptachlor Epoxide", "Heptachlor Epoxide, Particulate", "Heptachlor Epoxide/Oxychlordane", "Heptachlor Epoxide/Oxychlordane, Particulate", "Heptachlor, Particulate", "Hexachlorobenzene", "Hexachlorobenzene, Particulate", "Hexazinone", "Hydroxyatrazine, 2-", "Hydroxycarbofuran, 3- ", "Hydroxypropanal, 3-", "Imazalil", "Indoxacarb", "Isofenphos", "Isoxaben", "Jasmolin-2", "Kepone", "Ketocarbofuran, 3-", "Leptophos", "Linuron", "Malathion", "Merphos", "Methamidophos", "Methidathion", "Methiocarb", "Methomyl", "Methoprene", "Methoxychlor", "Methoxychlor, Particulate", "Methoxyfenozide", "Methyl (3,4-dichlorophenyl)carbamate", "Mevinphos", "Mexacarbate", "Mirex", "Mirex, Particulate", "Molinate", "Monocrotophos", "Monuron", "Naled", "Neburon", "Nonachlor, cis-", "Nonachlor, cis-, Particulate", "Nonachlor, trans-", "Nonachlor, trans-, Particulate", "Norflurazon", "Oxadiazon", "Oxadiazon, Particulate", "Oxamyl", "Oxychlordane", "Oxychlordane, Particulate", "Oxyfluorfen", "Paraquat", "Parathion, Ethyl", "Parathion, Methyl", "PCNB", "Pebulate", "Pendimethalin", "Penoxsulam", "Permethrin", "Permethrin, cis-", "Permethrin, trans-", "Perthane", "Phenothrin", "Phorate", "Phosalone", "Phosmet", "Phosphamidon", "Piperonyl Butoxide", "Pirimiphos Methyl", "PrAllethrin", "Procymidone", "Profenofos", "Profluralin", "Prometon", "Prometryn", "Propachlor", "Propanil", "Propargite", "Propazine", "Propham", "Propoxur", "Pymetrozin", "Pyrethrin-2", "Pyrimethanil", "Quinoxyfen", "Resmethrin", "Safrotin", "Secbumeton", "Siduron", "Simazine", "Simetryn", "Sulfallate", "Sulfotep", "Tebuthiuron", "Tedion", "Terbufos", "Terbuthylazine", "Terbutryn", "Tetrachloro-m-xylene", "Tetrachlorvinphos", "Tetraethyl Pyrophosphate", "Tetramethrin", "T-Fluvalinate", "Thiamethoxam", "Thiobencarb", "Thionazin", "Tokuthion", "Total DDDs", "Total DDEs", "Total DDTs", "Total HCHs", "Total Pyrethrins", "Toxaphene", "Tralomethrin", "Tributyl Phosphorotrithioate, S,S,S-", "Trichlorfon", "Trichloronate", "Triclopyr", "Tridimephon", "Vinclozolin", ]
	path = 'C:\\Users\\AHill\\Documents\\CEDEN_DataMart'
	fileName = 'WaterChemistryData_1994-2017.txt'
	newFileName = 'Pesticides_DW_AN.txt'
	column_filter = 'DW_AnalyteName'
	selectByAnalyte(path=path, fileName=fileName, newFileName=newFileName, analytes=analytes, field_filter=field_filter)
