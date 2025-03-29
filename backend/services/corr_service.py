from langchain_community.llms import Ollama
from langchain.prompts import ChatPromptTemplate
from utils.processing import extract_sentences, save_model_output
from datetime import datetime
import random
import re

# function to introduce typos based on keyboard proximity
def butterfinger(text,prob=0.2,keyboard='querty'):

	keyApprox = {}
	
	if keyboard == "querty":
		keyApprox['q'] = "wasedzx"
		keyApprox['w'] = "qesadrfcx"
		keyApprox['e'] = "wrsfdqazxcvgt"
		keyApprox['r'] = "etdgfwsxcvgt"
		keyApprox['t'] = "ryfhgedcvbnju"
		keyApprox['y'] = "tugjhrfvbnji"
		keyApprox['u'] = "yihkjtgbnmlo"
		keyApprox['i'] = "uojlkyhnmlp"
		keyApprox['o'] = "ipklujm"
		keyApprox['p'] = "lo['ik"

		keyApprox['a'] = "qszwxwdce"
		keyApprox['s'] = "wxadrfv"
		keyApprox['d'] = "ecsfaqgbv"
		keyApprox['f'] = "dgrvwsxyhn"
		keyApprox['g'] = "tbfhedcyjn"
		keyApprox['h'] = "yngjfrvkim"
		keyApprox['j'] = "hknugtblom"
		keyApprox['k'] = "jlinyhn"
		keyApprox['l'] = "okmpujn"

		keyApprox['z'] = "axsvde"
		keyApprox['x'] = "zcsdbvfrewq"
		keyApprox['c'] = "xvdfzswergb"
		keyApprox['v'] = "cfbgxdertyn"
		keyApprox['b'] = "vnghcftyun"
		keyApprox['n'] = "bmhjvgtuik"
		keyApprox['m'] = "nkjloik"
		keyApprox[' '] = " "
	else:
		print("Keyboard not supported.")

	probOfTypoArray = []
	probOfTypo = int(prob * 100)

	buttertext = ""

	# added to ensure max of 2 wrong chars
	errors = 0

	for letter in text:
		lcletter = letter.lower()
		if not lcletter in keyApprox.keys():
			newletter = lcletter
		else:
			# ensure no more than 2 errors
			if random.choice(range(0, 100)) <= probOfTypo and errors < 1:
				errors += 1
				if random.choice(range(0, 100)) <= 80:
					newletter = random.choice(keyApprox[lcletter])
				# add 50% prob of dropping chars
				else:
					# print("skipping! ", text)
					continue
			else:
				newletter = lcletter
		# go back to original case
		if not lcletter == letter:
			newletter = newletter.upper()
		buttertext += newletter

	return buttertext


def has_slash_or_two_or_more_uppercase(word):
    # Regular expression to match words with a '/' or two or more uppercase letters
    # pattern = re.compile(r'.*[/].*|.*[A-Z].*[A-Z].*')
    pattern = re.compile(r'\b\w{5,}/\w{5,}\b|\b(?:\w*[A-Z]){2,}\w*\b')

    
    # Check if the word matches the pattern
    return bool(pattern.match(word))


# method to introduce spelling mistakes to sentence (uses butterfinger function above)
def add_mistakes(text):
    words = text.split()
    mistake = ""

    errors = 0
    for word in words:
        # randomly select no more than 5 words to generate mispellings
        # if word is not abbrev, introduce spelling errors (using heuristic)
            # abbreviations usually fewer than 4 characters long (e.g pt, hiv)
            # or has slashes (e.g h/o, n/v) and is longer than 4 chars
            # or has caps
        probOfTypo = int(0.3 * 100) # set prob of error to be 0.3
        if errors < 5 and random.choice(range(0, 100)) <= probOfTypo and (len(word) >= 4 and not has_slash_or_two_or_more_uppercase(word) and word != "___"):
            mistake += butterfinger(word) + " "
            errors += 1
        else:
            mistake += word + " "

    return mistake.strip()


# method to correct spelling errors within a sentence
def correct_spelling(text, model_name):

    llm = Ollama(model=model_name)

    spelling_correction_prompt_template = ChatPromptTemplate.from_messages(
        [
            ("system", "Your job is to return the input with ALL spelling errors corrected. DO NOT expand any abbreviations."),
            ("system", "Input consist of clinical notes. Keep all occurrences of ___ in the output."),
            ("system", "Do NOT include supplementary messages like -> Here is the corrected input. Return the corrected input only."),
            ("human", "{input}"),
        ]
    )

    chain = spelling_correction_prompt_template | llm
    response = chain.invoke({
        "input" : text
    })

    return response


# method to test spelling correction
def generate_spellCorr_samples(dataset_path, headers, samples, model_name, save_path):
    
    # get list of sentences from notes
    sentences = extract_sentences(dataset_path, headers, samples)

    # specify unique output file names
    mod_name = ""
    if model_name == "llama3":
        mod_name = "llama3_7b"
    elif model_name == "meta.llama3-70b-instruct-v1:0":
        mod_name = "llama3_70b"
    save_file = "spell_cor_" + mod_name + "_" + str(samples) + "_" + str(datetime.now()) + ".json"

    # for each sentence extracted
    for st in sentences:
        sent = st['input']

        # introduce spelling errors
        sent_with_errors = add_mistakes(sent)

        # correct spelling using model
        output = correct_spelling(sent_with_errors, model_name)

        json = {
            "input": sent,
            "with_errors": sent_with_errors,
            "output": output
        }

        print(json)

        save_model_output(json, save_path, save_file)