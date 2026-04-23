import fitz
import json

def explore_pdf(pdf_path):
    print(f"Opening {pdf_path}...")
    try:
        doc = fitz.open(pdf_path)
    except Exception as e:
        print(f"Failed to open PDF: {e}")
        return

    print(f"Total pages: {len(doc)}")
    
    # Check first 50 pages for 'Table of Contents' or 'District' headings
    toc = doc.get_toc()
    if toc:
        print("Found Table of Contents:")
        for t in toc:
            if 'district' in t[1].lower():
                print(f"  {t}")
    else:
        print("No TOC found. Searching first 50 pages...")
        for i in range(min(50, len(doc))):
            page = doc.load_page(i)
            text = page.get_text()
            if 'district' in text.lower():
                print(f"Found 'district' on page {i+1}")
                # print snippet
                idx = text.lower().find('district')
                print("  Snippet:", text[max(0, idx-100):min(len(text), idx+100)].replace('\n', ' '))

if __name__ == '__main__':
    explore_pdf(r'assets\1701607577CrimeinIndia2022Book1.pdf')
