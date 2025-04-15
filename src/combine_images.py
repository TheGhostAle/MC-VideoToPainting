import os
from PIL import Image, ImageOps
import argparse
from tqdm import tqdm  # Importa tqdm per la barra di avanzamento
import re  # Importa la libreria per le espressioni regolari

def combine_images(input_dir, output_file, start_index=None, end_index=None):
    # Ottieni la lista delle immagini supportate
    image_extensions = {'.jpg', '.jpeg', '.png', '.gif', '.bmp'}
    files = [f for f in os.listdir(input_dir) 
            if os.path.splitext(f)[1].lower() in image_extensions]

    if not files:
        print("Nessun file immagine trovato nella cartella specificata.")
        return

    # Ordina i file numericamente
    def extract_number(file_name):
        # Estrae il numero dal nome del file usando una regex
        match = re.search(r'(\d+)', file_name)
        return int(match.group(0)) if match else float('inf')  # Restituisce un numero molto grande se non ci sono numeri

    files.sort(key=extract_number)

    # Filtra le immagini in base a start_index e end_index
    if start_index is not None and end_index is not None:
        files = files[start_index:end_index + 1]
    elif start_index is not None:
        files = files[start_index:]
    elif end_index is not None:
        files = files[:end_index + 1]

    if not files:
        print("Nessuna immagine valida nell'intervallo specificato.")
        return

    images = []
    max_width = 0
    total_height = 0

    # Processa ogni immagine con una barra di avanzamento
    for file in tqdm(files, desc="Elaborazione immagini", unit="img"):
        try:
            filepath = os.path.join(input_dir, file)
            img = Image.open(filepath)
            img = ImageOps.exif_transpose(img)  # Corregge l'orientamento EXIF
            
            # Gestione trasparenza e conversione a RGB
            if img.mode in ('RGBA', 'LA'):
                bg = Image.new('RGB', img.size, (255, 255, 255))
                bg.paste(img, mask=img.split()[-1])
                img = bg
            else:
                img = img.convert('RGB')
            
            images.append(img)
            max_width = max(max_width, img.width)
            total_height += img.height
        except Exception as e:
            print(f"Errore nel processare {file}: {str(e)}")
            continue

    if not images:
        print("Nessuna immagine valida da processare.")
        return

    # Crea l'immagine combinata
    combined_image = Image.new('RGB', (max_width, total_height), (255, 255, 255))
    y_offset = 0
    
    # Aggiungi una barra di avanzamento anche per l'incollaggio delle immagini
    for img in tqdm(images, desc="Creazione immagine combinata", unit="img"):
        combined_image.paste(img, (0, y_offset))
        y_offset += img.height

    # Salva l'immagine risultante
    combined_image.save(output_file)

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description='Combina immagini verticalmente')
    parser.add_argument('input_dir', help='Cartella contenente le immagini')
    parser.add_argument('output_file', help='Nome del file output')
    parser.add_argument('--start', type=int, help='Indice di partenza (inclusivo)')
    parser.add_argument('--end', type=int, help='Indice di fine (inclusivo)')
    args = parser.parse_args()

    combine_images(args.input_dir, args.output_file, args.start, args.end)




# python script.py final_output percorso_output.png --start 10 --end 20