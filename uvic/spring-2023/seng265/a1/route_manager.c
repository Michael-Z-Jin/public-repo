/** @file route_manager.c
 *  @brief A pipes & filters program that uses conditionals, loops, and string processing tools in C to process airline routes.
 *  @author Felipe R.
 *  @author Hausi M.
 *  @author Jose O.
 *  @author Saasha J.
 *  @author Victoria L.
 *  @author Michael Jin
 *
 */
#include <stdio.h>
#include <string.h>
#include <stdlib.h>

#define MAX_PATH_LEN 256    // Set the maximum length of input file path to a constant value. This is not a global variable.
#define MAX_FILTER_LEN 32   // Set the maximum length of each filter to a constant value. This is not a global variable.
#define MAX_LINE_LEN 512    // Set the maximum length of each csv line to a constant value. This is not a global variable.

/* Flight stores the information from each csv line. */
struct Flight {
    char a_name[128];   // airline_name
    char a_code[128];   // airline_icao_unique_code
    char a_cntr[128];   // airline_country
    char f_arpt[128];   // from_airport_name
    char f_city[128];   // from_airport_city
    char f_cntr[128];   // from_airport_country
    char f_code[128];   // from_airport_icao_unique_code
    char f_altd[128];   // from_airport_altitude
    char t_arpt[128];   // to_airport_name
    char t_city[128];   // to_airport_city
    char t_cntr[128];   // to_airport_country
    char t_code[128];   // to_airport_icao_unique_code
    char t_altd[128];   // to_airport_altitude
};

/**
 * Function: read_arg
 * ------------------
 * @brief Parse a command line argument.
 * 
 * @param input The command line argument.
 * @param value The parsed argument.
 * @return Void.
 * 
 */
void read_arg(char* input, char* value);

/**
 * Function: parse_str
 * -------------------
 * @brief Tokenize a csv string.
 * 
 * @param str The csv string.
 * @param flight The structure that stores the tokens.
 * @return Void.
 * 
 */
void parse_str(char* str, struct Flight* flight);

/**
 * Function: compare
 * -----------------
 * @brief Compare the information of a flight with a list of filters.
 * 
 * @param flight The structure that contains flight information.
 * @param filters The list of filters.
 * @param num_of_args The number that decides which pieces of information are compared with which filters.
 * @return int 0: The flight matches the filters; 1: The flight does not match the filters.
 * 
 */
int compare(struct Flight flight, char filters[][MAX_FILTER_LEN], int num_of_args);

/**
 * Function: write_output
 * ----------------------
 * @brief Print flight information to an output stream.
 * 
 * @param flight The structure that contains flight information.
 * @param out_file The output stream.
 * @param num_of_args The number that controls which pieces of information should be print.
 * @param header_toggle A flag that controls whether or not a header should be print. 0: No header; 1: Print header.
 * @return Void.
 * 
 */
void write_output(struct Flight flight, FILE* out_file, int num_of_args, int header_toggle);

/**
 * Function: main
 * --------------
 * @brief The main function and entry point of the program.
 *
 * @param argc The number of arguments passed to the program.
 * @param argv The list of arguments passed to the program.
 * @return int 0: No errors; 1: Errors produced.
 *
 */
int main(int argc, char *argv[])
{
    // TODO: your code.

    /* Set Up File Input Stream and File Output Stream */
    char DATA[MAX_PATH_LEN] = {'\0'};                       // Long length in case of long file path.
    read_arg(argv[1], DATA);

    FILE* ifp;                                              // Input File Pointer
    if ( (ifp = fopen(DATA, "r")) == NULL ) {
        printf("Error: Input file was not found!\n");
    }
    FILE* ofp;                                              // Output File Pointer
    if ( (ofp = fopen("output.txt", "w")) == NULL ) {
        printf("Error: Output file was not found!\n");
    }

    /* Read User Filters */
    int FLTRLST_length = argc - 2;                          // Filter List length, i.e., minus program_name and DATA.
    char FLTRLST[FLTRLST_length][MAX_FILTER_LEN];           // Filter List
    for (int i = 0; i < FLTRLST_length; i++) {
        read_arg(argv[i+2], FLTRLST[i]);                    // Parse the input at the proper argv location and put it in FLTRLST.
    }

    /* Loop: Read Each Line */
    char line[MAX_LINE_LEN];
    struct Flight flight;
    int header_toggle = 1;
    /*                 Start of Loop                 */
    while (fgets(line, MAX_LINE_LEN, ifp) != NULL) {

        /* Parse Line */
        parse_str(line, &flight);                           // Pass by reference.

        /* Compare Parsed Tokens with User Filters */
        if ( !compare(flight, FLTRLST, argc) ) {            // Write output if they match.
            write_output(flight, ofp, argc, header_toggle);
            header_toggle = 0;
        }

    }
    /*                  End of Loop                  */

    /* Write Output If No Matching Lines Are Found */
    if (header_toggle) {                                    // If header_toggle is still set, then no lines have been written.
        fprintf(ofp, "NO RESULTS FOUND.\n");
    }

    /* Wrap Things Up */
    fclose(ifp);
    fclose(ofp);

    exit(0);

}


void read_arg(char* input, char* value) {

    char label[32];
    // A newline character will never be encountered in the args.
    // This in practice causes sscanf() to read until \0.
    // Using %[^\0] will cause the compiler to scream.
    sscanf(input, "%[^=]=%[^\n]", label, value);
    
}


void parse_str(char* str, struct Flight* flight) {
// flight is passed by reference since it will be modified.
    sscanf(str, "%[^,],%[^,],%[^,],%[^,],%[^,],%[^,],%[^,],%[^,],%[^,],%[^,],%[^,],%[^,],%[^,]", 
    flight->a_name, flight->a_code, flight->a_cntr, 
    flight->f_arpt, flight->f_city, flight->f_cntr, flight->f_code, flight->f_altd, 
    flight->t_arpt, flight->t_city, flight->t_cntr, flight->t_code, flight->t_altd);
    
}


int compare(struct Flight flight, char filters[][MAX_FILTER_LEN], int num_of_args) {

    int flag = 1;   // 1 = different. 0 = same.
    switch (num_of_args) {
        case 4: flag = ( strcmp(flight.a_code, filters[0]) || strcmp(flight.t_cntr, filters[1]) );
                break;
        case 5: flag = ( strcmp(flight.f_cntr, filters[0]) || strcmp(flight.t_city, filters[1]) || strcmp(flight.t_cntr, filters[2]) );
                break;
        case 6: flag = ( strcmp(flight.f_city, filters[0]) || strcmp(flight.f_cntr, filters[1]) || strcmp(flight.t_city, filters[2]) || 
                strcmp(flight.t_cntr, filters[3]) );
                break;
    }
    return flag;

}


void write_output(struct Flight flight, FILE* out_file, int num_of_args, int header_toggle) {

    switch(num_of_args) {
        case 4: if (header_toggle) {
                    fprintf(out_file, "FLIGHTS TO %s BY %s (%s):\n", flight.t_cntr, flight.a_name, flight.a_code);
                }
                fprintf(out_file, "FROM: %s, %s, %s TO: %s (%s), %s\n", 
                flight.f_code, flight.f_city, flight.f_cntr, flight.t_arpt, flight.t_code, flight.t_city);
                break;
        case 5: if (header_toggle) {
                    fprintf(out_file, "FLIGHTS FROM %s TO %s, %s:\n", flight.f_cntr, flight.t_city, flight.t_cntr);
                }
                fprintf(out_file, "AIRLINE: %s (%s) ORIGIN: %s (%s), %s\n", flight.a_name, flight.a_code, flight.f_arpt, flight.f_code, flight.f_city);
                break;
        case 6: if (header_toggle) {
                    fprintf(out_file, "FLIGHTS FROM %s, %s TO %s, %s:\n", flight.f_city, flight.f_cntr, flight.t_city, flight.t_cntr);
                }
                fprintf(out_file, "AIRLINE: %s (%s) ROUTE: %s-%s\n", flight.a_name, flight.a_code, flight.f_code, flight.t_code);
                break;
    }
    
}