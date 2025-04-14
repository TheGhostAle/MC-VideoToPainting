import cv2
import sys
import os

def calculate_optimal_scale(original_width, original_height, max_window_ratio=0.75):
    screen_width = 1920
    screen_height = 1080
    try:
        screen_width = cv2.getWindowImageRect('dummy')[2] if cv2.getWindowProperty('dummy', 0) >= 0 else 1920
        screen_height = cv2.getWindowImageRect('dummy')[3] if cv2.getWindowProperty('dummy', 0) >= 0 else 1080
    except:
        pass
    
    max_window_width = screen_width * max_window_ratio
    max_window_height = screen_height * max_window_ratio
    
    scale_width = max_window_width / original_width
    scale_height = max_window_height / (original_height * 2/3)
    
    optimal_scale = min(scale_width, scale_height)
    
    optimal_scale = max(1, int(optimal_scale))
    
    optimal_scale = min(8, optimal_scale)
    
    return optimal_scale

def main(image_path):
    if not os.path.exists(image_path):
        print(f"File non trovato: {image_path}")
        return
    
    img = cv2.imread(image_path)
    if img is None:
        print(f"Impossibile caricare l'immagine: {image_path}")
        return
    
    frame_width = img.shape[1]
    frame_height = frame_width
    num_frames = img.shape[0] // frame_height

    scale = calculate_optimal_scale(frame_width, frame_height)

    running = True
    while running:
        for i in range(num_frames):
            y = i * frame_height
            frame = img[y:y+frame_height, 0:frame_width]

            display_width = frame_width * scale
            display_height = int((frame_height * 2 / 3) * scale)

            resized = cv2.resize(frame, (display_width, display_height), interpolation=cv2.INTER_NEAREST)

            cv2.imshow("Anteprima Animazione", resized)

            key = cv2.waitKey(100)
            if key == 27 or cv2.getWindowProperty("Anteprima Animazione", cv2.WND_PROP_VISIBLE) < 1:
                running = False
                break

    cv2.destroyAllWindows()

if __name__ == "__main__":
    if len(sys.argv) < 2:
        print("Usage: python preview.py <image_path>")
        sys.exit(1)
    
    main(sys.argv[1])