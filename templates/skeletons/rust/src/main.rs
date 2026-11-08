fn saludo() -> &'static str {
    "hola"
}

fn main() {
    println!("{}", saludo());
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn saluda() {
        assert_eq!(saludo(), "hola");
    }
}
