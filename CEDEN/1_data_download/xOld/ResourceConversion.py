import os, csv

path = 'C:\\Users\\AHill\\Documents\\CEDEN_Datasets'
name = 'WaterChemistryData'
ext = '.csv'
file = os.path.join(path,name + ext)
os.path.isfile(file)
fileOut = os.path.join(path, name + '.tsv')
with open(file, 'r', newline='', encoding='utf8') as txtfile:
	reader = csv.reader(txtfile, delimiter=',', lineterminator='\n')
	with open(fileOut, 'w', newline='', encoding='utf8') as txtfileOut:
		writer = csv.writer(txtfileOut, csv.QUOTE_MINIMAL, delimiter=',', lineterminator='\n')
		count = 0
		for row in reader:
			if count == 0:
				columns = row
				writer.writerow(row)
				count += 1
				continue
			writer.writerow(row)
