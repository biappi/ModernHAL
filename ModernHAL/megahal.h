#ifndef MEGAHAL_H
#define MEGAHAL_H 1

/*===========================================================================*/

/*
 *  Copyright (C) 1998 Jason Hutchens
 *
 *  This program is free software; you can redistribute it and/or modify it
 *  under the terms of the GNU General Public License as published by the Free
 *  Software Foundation; either version 2 of the license or (at your option)
 *  any later version.
 *
 *  This program is distributed in the hope that it will be useful, but
 *  WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY
 *  or FITNESS FOR A PARTICULAR PURPOSE.  See the Gnu Public License for more
 *  details.
 *
 *  You should have received a copy of the GNU General Public License along
 *  with this program; if not, write to the Free Software Foundation, Inc.,
 *  675 Mass Ave, Cambridge, MA 02139, USA.
 */

/*===========================================================================*/

/*
 *		$Id: megahal.h,v 1.8 2004/02/25 20:19:39 lfousse Exp $
 *
 *		File:			megahal.h
 *
 *		Program:		MegaHAL
 *
 *		Purpose:		To simulate a natural language conversation with a psychotic
 *						computer.  This is achieved by learning from the user's
 *						input using a third-order Markov model on the word level.
 *						Words are considered to be sequences of characters separated
 *						by whitespace and punctuation.  Replies are generated
 *						randomly based on a keyword, and they are scored using
 *						measures of surprise.
 *
 *		Author:		Mr. Jason L. Hutchens
 *
 *		WWW:			http://megahal.sourceforge.net
 *
 *		E-Mail:		hutch@ciips.ee.uwa.edu.au
 *
 *		Contact:		The Centre for Intelligent Information Processing Systems
 *						Department of Electrical and Electronic Engineering
 *						The University of Western Australia
 *						AUSTRALIA 6907
 *
 */

/*===========================================================================*/

/* public functions  */

void megahal_setnoprompt (void);
void megahal_setnowrap (void);
void megahal_setnobanner (void);

void megahal_seterrorfile(char *filename);
void megahal_setstatusfile(char *filename);
void megahal_setdirectory (char *dir);

void megahal_initialize(void);

char *megahal_initial_greeting(void);

int megahal_command(char *input);

char *megahal_do_reply(char *input, int log);
void megahal_learn_no_reply(char *input, int log);
void megahal_output(char *output);
char *megahal_input(char *prompt);

void megahal_cleanup(void);

/* internals */

#include <stdio.h>
#include <stdbool.h>

typedef struct {
    uint8_t length;
    char *word;
} STRING;

typedef struct {
    uint32_t size;
    STRING *entry;
    uint16_t *index;
} DICTIONARY;

typedef struct {
    uint16_t size;
    STRING *from;
    STRING *to;
} SWAP;

typedef struct NODE {
    uint16_t symbol;
    uint32_t usage;
    uint16_t count;
    uint16_t branch;
    struct NODE **tree;
} TREE;

typedef struct {
    uint8_t order;
    TREE *forward;
    TREE *backward;
    TREE **context;
    DICTIONARY *dictionary;
} MODEL;

typedef enum { UNKNOWN, QUIT, EXIT, SAVE, DELAY, HELP, SPEECH, VOICELIST, VOICE, BRAIN, QUIET} COMMAND_WORDS;

typedef struct {
    STRING word;
    char *helpstring;
    COMMAND_WORDS command;
} COMMAND;

/*===========================================================================*/

void add_aux(MODEL *, DICTIONARY *, STRING);
void add_key(MODEL *, DICTIONARY *, STRING);
void add_node(TREE *, TREE *, int);
void add_swap(SWAP *, char *, char *);
TREE *add_symbol(TREE *, uint16_t);
uint16_t add_word(DICTIONARY *, STRING);
int babble(MODEL *, DICTIONARY *, DICTIONARY *);
bool boundary(char *, int);
void capitalize(char *);
void change_personality(DICTIONARY *, unsigned int, MODEL **);
void delay(char *);
void die(int);
bool dissimilar(DICTIONARY *, DICTIONARY *);
void error(char *, char *, ...);
float evaluate_reply(MODEL *, DICTIONARY *, DICTIONARY *);
COMMAND_WORDS execute_command(DICTIONARY *, int *);
void exithal(void);
TREE *find_symbol(TREE *, int);
TREE *find_symbol_add(TREE *, int);
uint16_t find_word(DICTIONARY *, STRING);
char *generate_reply(MODEL *, DICTIONARY *);
void help(void);
void ignore(int);
bool initialize_error(char *);
bool initialize_status(char *);
void learn(MODEL *, DICTIONARY *);
void make_greeting(DICTIONARY *);
void make_words(char *, DICTIONARY *);
DICTIONARY *new_dictionary(void);

char *read_input(char *);
void save_model(char *, MODEL *);
void upper(char *);
void write_input(char *);
void write_output(char *);

char *format_output(char *);
void free_dictionary(DICTIONARY *);
void free_model(MODEL *);
void free_tree(TREE *);
void free_word(STRING);
void free_words(DICTIONARY *);
void initialize_context(MODEL *);
void initialize_dictionary(DICTIONARY *);
DICTIONARY *initialize_list(char *);
SWAP *initialize_swap(char *);
void load_dictionary(FILE *, DICTIONARY *);
bool load_model(char *, MODEL *);
void load_personality(MODEL **);
void load_tree(FILE *, TREE *);
void load_word(FILE *, DICTIONARY *);
DICTIONARY *make_keywords(MODEL *, DICTIONARY *);
char *make_output(DICTIONARY *);
MODEL *new_model(int);
TREE *new_node(void);
SWAP *new_swap(void);
bool print_header(FILE *);
bool progress(char *, int, int);
DICTIONARY *reply(MODEL *, DICTIONARY *);
void save_dictionary(FILE *, DICTIONARY *);
void save_tree(FILE *, TREE *);
void save_word(FILE *, STRING);
int search_dictionary(DICTIONARY *, STRING, bool *);
int search_node(TREE *, int, bool *);
int seed(MODEL *, DICTIONARY *);
void show_dictionary(DICTIONARY *);
bool status(char *, ...);
void train(MODEL *, char *);
void typein(char);
void update_context(MODEL *, int);
void update_model(MODEL *, int);
int wordcmp(STRING, STRING);
bool word_exists(DICTIONARY *, STRING);
int rnd(int);

extern DICTIONARY *words;
extern MODEL *model;
extern bool used_key;
extern SWAP *swp;
extern DICTIONARY *ban;
extern DICTIONARY *aux;

#endif /* MEGAHAL_H  */
