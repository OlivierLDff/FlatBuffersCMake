#include <vector>
#include <string>
#include <regex>

#include <stdio.h>
#include <stdlib.h>
#include <string.h>

#define BUFFER_SIZE 32738

static void print_help(const char* name)
{
    printf("OVERVIEW: Converts flatbuffers schema .fbs to C header\n\n");
    printf("USAGE: %s -i <input> -o <output> -n <name> -d -z\n\n", name);
    printf("OPTIONS:\n");
    printf("    -i <input>      Specify input file\n");
    printf("    -o <output>     Specify output file\n");
}

int main(int argc, char *argv[])
{
    int result = EXIT_FAILURE;
    int i = 0;
    int arg;
    FILE* input_f = NULL;
    FILE* output_f = NULL;
    const char* input = NULL;
    const char* output = NULL;
    std::string s;
    std::smatch m;
    std::regex e("([\\w-]+)\\.fbs");
    std::string className;

    int byte;

    std::string guard = "__";
    char str[BUFFER_SIZE];
    char* pos;
    std::vector<std::string> namespaces;

    if (argc <= 1 ||
        (argc == 2 && strcmp(argv[1], "-h") == 0))
    {
        print_help((argc > 0) ? argv[0] : "flat2h");
        return EXIT_SUCCESS;
    }

    for (arg = 1; arg < argc; ++arg)
    {
        if (strcmp(argv[arg], "-i") == 0)
        {
            if (++arg >= argc)
            {
                printf("Missing argument for -i\n");
                return EXIT_FAILURE;
            }
            input = argv[arg];
        }
        else if (strcmp(argv[arg], "-o") == 0)
        {
            if (++arg >= argc)
            {
                printf("Missing argument for -o\n");
                return EXIT_FAILURE;
            }
            output = argv[arg];
        }
        else
        {
            printf("Invalid argument: %s\n", argv[arg]);
            return EXIT_FAILURE;
        }
    }

    if (!input)
    {
        printf("No input file given\n");
        goto exit;
    }

    if (!output)
    {
        printf("No output file given\n");
        goto exit;
    }

    input_f = fopen(input, "rb");

    if (!input_f)
    {
        printf("Failed to open input file\n");
        goto exit;
    }

    output_f = fopen(output, "w");

    if (!output_f)
    {
        printf("Failed to open output file\n");
        goto exit;
    }

    while (namespaces.empty() && (fgets(str, BUFFER_SIZE, input_f) != NULL))
    {
        // Find next occurrence of word in str
        if ((pos = strstr(str, "namespace")) != NULL)
        {
            const char* separators = " .;";

            // Look for every namespace
            char* strToken = strtok(pos, separators);

            while (strToken != NULL)
            {
                if (strToken[0] == '\n' || strToken[0] == '\r')
                {
                    break;
                }
                if (strcmp(strToken, "namespace") != 0)
                {
                    namespaces.emplace_back(strToken);
                }
                strToken = strtok(NULL, separators);
            }
        }
    }

    s = std::string(input);
    if (std::regex_search(s, m, e))
    {
        if (m.size() <= 1)
        {
            printf("Failed to parse class name\n");
            goto exit;
        }
        className = m[1].str();
    }

    for (const auto& it : namespaces)
    {
        std::string upper(it);
        for (auto& c : upper) c = toupper(c);
        guard += upper;
        guard += "_";
    }
    {
        std::string upper(className);
        for (auto& c : upper) c = toupper(c);
        guard += upper;
        guard += "_";
    }
    guard += "H__";

    fseek(input_f, 0, SEEK_SET);
    fprintf(output_f, "#ifndef %s\n", guard.c_str());
    fprintf(output_f, "#define %s\n\n", guard.c_str());
    fprintf(output_f, "/** File generated with flat2h, do not modify. */\n\n");
    for (const auto& it : namespaces)
        fprintf(output_f, "namespace %s {\n", it.c_str());

    fprintf(output_f, "\nclass %sRc \n{\npublic:\n", className.c_str());

    fprintf(output_f, "    static const char* data()\n    {\n");

    fprintf(output_f, "        static const char d[] = \n        {\n        ");
    while ((byte = getc(input_f)) != EOF)
    {
        if (i != 0) fprintf(output_f, ", ");
        fprintf(output_f, "0x%02X", byte);
        ++i;
    }

    if (i != 0) fprintf(output_f, ", ");
    fprintf(output_f, "0x00");
    ++i;

    fprintf(output_f, "\n        };\n");

    fprintf(output_f, "        return d;\n    }\n");

    fprintf(output_f, "    static const char* path()\n    {\n");
    fprintf(output_f, "        return \"");

    for (const auto& it : namespaces)
        fprintf(output_f, "%s/", it.c_str());
    fprintf(output_f, "%s.fbs\"", className.c_str());
    fprintf(output_f, ";\n    }\n");

    fprintf(output_f, "    static const char* directory()\n    {\n");
    fprintf(output_f, "        return \"");

    for (const auto& it : namespaces)
        fprintf(output_f, "%s/", it.c_str());
    fprintf(output_f, "\";\n    }\n");

    fprintf(output_f, "};\n\n");

    for (const auto& it : namespaces)
        fprintf(output_f, "}\n");
    fprintf(output_f, "\n#endif\n");

    result = EXIT_SUCCESS;
exit:
    if (input_f) fclose(input_f);
    if (output_f) fclose(output_f);

    return result;
}
